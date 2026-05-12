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
        // 文件已播放到末尾
        player.stop()
        stopPositionTimer()
        currentTime = duration
        state = .idle
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
            Task { @MainActor in self?.updateCurrentTime() }
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
