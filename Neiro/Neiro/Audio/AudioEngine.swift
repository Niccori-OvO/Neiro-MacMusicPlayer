//
//  AudioEngine.swift
//  Neiro
//
//  基于 AVAudioEngine 的播放引擎。
//
//  设计原则（v0.2 重写）：
//    - 简单：用 Apple 自家 AVAudioEngine 而非手撸 CoreAudio IOProc，
//      自动处理设备变化、蓝牙/AirPlay/USB DAC/HDMI/内置喇叭。
//    - 兼容：AVAudioFile 原生支持 FLAC / ALAC / WAV / AIFF / M4A / MP3。
//    - 高质量：AVAudioEngine 末端走 vDSP 加速的高质量重采样，
//      送给设备的永远是设备原生支持的格式，不会因为采样率不匹配卡死。
//    - 高性能：Apple 内核优化的 buffer 调度，蓝牙耳机也能稳。
//

import Foundation
import AVFoundation
import Observation
import os

@MainActor
@Observable
public final class AudioEngine {

    public enum PlaybackState: Equatable {
        case idle
        case playing
        case paused
        case error(String)
    }

    // MARK: - Observed

    public private(set) var state: PlaybackState = .idle
    public private(set) var currentURL: URL?
    /// 源文件原生格式（仅展示用）。
    public private(set) var sourceSampleRate: Double = 0
    public private(set) var sourceBitDepth: Int = 0
    public private(set) var sourceChannels: Int = 0

    public private(set) var duration: TimeInterval = 0
    public private(set) var currentTime: TimeInterval = 0

    public var volume: Float = 1.0 {
        didSet { engine.mainMixerNode.outputVolume = max(0, min(1, volume)) }
    }

    // MARK: - 播放队列

    /// 当前队列（URL 列表）。
    public private(set) var queue: [URL] = []
    /// 队列里当前正在播放的 index，没有就是 nil。
    public private(set) var currentIndex: Int? = nil

    public enum RepeatMode: String, CaseIterable { case off, one, all }
    public var repeatMode: RepeatMode = .off
    public var isShuffleEnabled: Bool = false {
        didSet {
            // 开启 shuffle 时从当前曲目重建顺序；关闭时清空（next 走顺序逻辑）
            if isShuffleEnabled {
                rebuildShuffleOrder(startingAt: currentIndex)
            } else {
                shuffledIndices = []
                shuffleCursor = 0
            }
        }
    }

    /// 当 shuffle 打开时记录的随机播放顺序，是 queue 的 index 顺序
    private var shuffledIndices: [Int] = []
    private var shuffleCursor: Int = 0

    // MARK: - Private

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var file: AVAudioFile?
    /// 当前文件的总帧数。
    private var totalFrames: AVAudioFramePosition = 0
    /// 当 player 被 stop 时，记下相对文件起点的偏移帧（用于 seek 后正确显示时间）。
    private var seekOffsetFrames: AVAudioFramePosition = 0
    /// 当前播放是否处于"调度结束"的清理过程，避免完成回调和用户操作打架。
    private var isFinishing = false
    /// 每次重新 schedule 都递增，避免旧的 completion 回调影响新播放状态。
    private var scheduleGeneration: UInt64 = 0

    private var securityScopedURL: URL?
    private var positionTimer: Timer?

    private static let log = Logger(subsystem: "app.neiro", category: "Engine")

    // MARK: - Init

    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = volume

        // 设备变化（拔耳机、切 AirPlay）后自动重连
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // 注意：security-scoped 句柄由 stop() 释放；这里 deinit 是 nonisolated，
        // 不再触碰 main-actor 隔离的属性。
    }

    // MARK: - Transport

    /// 打开并立即开始播放。
    public func load(url: URL) {
        stop()

        // Sandbox / .fileImporter 给的 URL 需要拿 security-scoped 访问
        if url.startAccessingSecurityScopedResource() {
            securityScopedURL = url
        }

        do {
            let f = try AVAudioFile(forReading: url)
            self.file = f
            self.currentURL = url
            self.totalFrames = f.length
            self.duration = Double(f.length) / f.processingFormat.sampleRate

            let pf = f.processingFormat
            self.sourceSampleRate = pf.sampleRate
            self.sourceChannels = Int(pf.channelCount)
            self.sourceBitDepth = bitDepth(from: pf)

            Self.log.info("opened '\(url.lastPathComponent)' \(Int(pf.sampleRate))Hz \(pf.channelCount)ch")

            try startEngineIfNeeded()
            scheduleAndPlay(from: 0)
            state = .playing
            startPositionTimer()
        } catch {
            Self.log.error("load failed: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
            cleanup()
        }
    }

    public func play() {
        guard let f = file, state == .paused else { return }
        do {
            try startEngineIfNeeded()
            // 续播：若 player 内部还有未播完的 buffer 直接 play() 续播。
            // 若 buffer 已经被消费完（罕见，但 dataConsumed 模式会发生），
            // 按当前 currentTime 重新 schedule 后再 play。
            if !player.isPlaying {
                if player.engine != nil {
                    player.play()
                }
                if !player.isPlaying {
                    // 兜底：用当前时间重新 schedule
                    let sr = f.processingFormat.sampleRate
                    let frame = AVAudioFramePosition(currentTime * sr)
                    scheduleAndPlay(from: frame, autoPlay: true)
                }
            } else {
                player.play()
            }
            state = .playing
            startPositionTimer()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func pause() {
        guard state == .playing else { return }
        player.pause()
        state = .paused
        stopPositionTimer()
    }

    public func stop() {
        isFinishing = true
        player.stop()
        engine.stop()
        stopPositionTimer()
        if let scoped = securityScopedURL {
            scoped.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
        }
        cleanup()
        state = .idle
        isFinishing = false
    }

    // MARK: - 队列控制

    /// 用 URL 列表替换当前队列并从指定 index 开始播放。
    public func playQueue(_ urls: [URL], startAt index: Int = 0, shuffle: Bool = false) {
        guard !urls.isEmpty else { stop(); return }
        queue = urls
        let safeIndex = max(0, min(index, urls.count - 1))
        currentIndex = safeIndex

        if shuffle {
            isShuffleEnabled = true
            rebuildShuffleOrder(startingAt: safeIndex)
        }
        load(url: urls[safeIndex])
    }

    /// 在队列中下一首
    public func nextTrack() {
        guard !queue.isEmpty, let cur = currentIndex else { return }
        let nextIdx = computeNextIndex(from: cur)
        guard let n = nextIdx else {
            // 到队尾：repeat off 就停止
            stop()
            return
        }
        currentIndex = n
        load(url: queue[n])
    }

    /// 在队列中上一首；当播放进度 > 3s 时改为从头开始
    public func previousTrack() {
        guard !queue.isEmpty, let cur = currentIndex else { return }
        if currentTime > 3 {
            seek(toSeconds: 0)
            return
        }
        let prevIdx = computePrevIndex(from: cur)
        guard let p = prevIdx else { return }
        currentIndex = p
        load(url: queue[p])
    }

    public func toggleShuffle() { isShuffleEnabled.toggle() }

    public func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    /// 内部：计算下一首 index
    private func computeNextIndex(from current: Int) -> Int? {
        if repeatMode == .one { return current }
        if isShuffleEnabled {
            shuffleCursor += 1
            if shuffleCursor >= shuffledIndices.count {
                if repeatMode == .all {
                    rebuildShuffleOrder()
                    shuffleCursor = 0
                } else {
                    return nil
                }
            }
            return shuffledIndices[shuffleCursor]
        } else {
            let nxt = current + 1
            if nxt >= queue.count {
                return repeatMode == .all ? 0 : nil
            }
            return nxt
        }
    }

    private func computePrevIndex(from current: Int) -> Int? {
        if repeatMode == .one { return current }
        if isShuffleEnabled {
            shuffleCursor = max(0, shuffleCursor - 1)
            guard shuffledIndices.indices.contains(shuffleCursor) else { return nil }
            return shuffledIndices[shuffleCursor]
        } else {
            let prev = current - 1
            if prev < 0 { return repeatMode == .all ? queue.count - 1 : nil }
            return prev
        }
    }

    private func rebuildShuffleOrder(startingAt: Int? = nil) {
        var all = Array(queue.indices)
        all.shuffle()
        // 把 startingAt 放在第一位
        if let s = startingAt, let pos = all.firstIndex(of: s) {
            all.swapAt(0, pos)
        }
        shuffledIndices = all
        shuffleCursor = 0
    }

    /// 跳到指定秒。
    public func seek(toSeconds seconds: TimeInterval) {
        guard let f = file else { return }
        let wasPlaying = (state == .playing)
        let sr = f.processingFormat.sampleRate
        let safeUpperBound = max(0, duration - 0.05)
        let clamped = max(0, min(seconds, safeUpperBound))
        let frame = AVAudioFramePosition(clamped * sr)
        currentTime = clamped
        player.stop()
        do {
            try startEngineIfNeeded()
            scheduleAndPlay(from: frame, autoPlay: wasPlaying)
            if wasPlaying { state = .playing } else { state = .paused }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Internals

    private func startEngineIfNeeded() throws {
        guard !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
    }

    private func scheduleAndPlay(from startFrame: AVAudioFramePosition,
                                 autoPlay: Bool = true) {
        guard let f = file else { return }
        let remaining = AVAudioFrameCount(max(0, totalFrames - startFrame))
        guard remaining > 0 else {
            state = .idle
            return
        }
        seekOffsetFrames = startFrame
        scheduleGeneration &+= 1
        let generation = scheduleGeneration

        // 关键：dataPlayedBack 表示样本真正被设备播完才触发回调，
        // pause() 不会因为预读 buffer 消费而误触发把状态切回 idle。
        player.scheduleSegment(f,
                               startingFrame: startFrame,
                               frameCount: remaining,
                               at: nil,
                               completionCallbackType: .dataPlayedBack) { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !self.isFinishing else { return }
                guard generation == self.scheduleGeneration else { return }
                self.handlePlaybackFinished()
            }
        }
        if autoPlay { player.play() }
    }

    private func handlePlaybackFinished() {
        // 文件已播放到末尾。若队列还有曲目，自动播放下一首。
        player.stop()
        stopPositionTimer()
        currentTime = duration

        if !queue.isEmpty, let cur = currentIndex, let next = computeNextIndex(from: cur) {
            currentIndex = next
            load(url: queue[next])
        } else {
            state = .idle
        }
    }

    private func cleanup() {
        file = nil
        totalFrames = 0
        seekOffsetFrames = 0
        duration = 0
        currentTime = 0
        currentURL = nil
        sourceSampleRate = 0
        sourceBitDepth = 0
        sourceChannels = 0
    }

    // MARK: - Position

    private func startPositionTimer() {
        stopPositionTimer()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.updateCurrentTime()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        positionTimer = t
    }

    private func stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
    }

    private func updateCurrentTime() {
        guard let f = file,
              let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return
        }
        let sr = f.processingFormat.sampleRate
        let elapsed = Double(seekOffsetFrames) / sr + Double(playerTime.sampleTime) / playerTime.sampleRate
        currentTime = max(0, min(elapsed, duration))
    }

    // MARK: - Device change

    @objc private func handleConfigurationChange(_ note: Notification) {
        // 设备热切换：AVAudioEngine 会自动 stop。我们尝试重新 start 并继续播放。
        let wasPlaying = (state == .playing)
        let snapshotFrame = AVAudioFramePosition(currentTime * (file?.processingFormat.sampleRate ?? 44100))
        do {
            try startEngineIfNeeded()
            if file != nil {
                scheduleAndPlay(from: snapshotFrame, autoPlay: wasPlaying)
            }
        } catch {
            Self.log.warning("re-init after device change failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func bitDepth(from format: AVAudioFormat) -> Int {
        // AVAudioFile.processingFormat 永远是 Float32；
        // 用 fileFormat / streamDescription 拿源比特深度更准确。
        guard let asbd = file?.fileFormat.streamDescription.pointee else { return 0 }
        if (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0 { return 32 }
        return Int(asbd.mBitsPerChannel)
    }
}
