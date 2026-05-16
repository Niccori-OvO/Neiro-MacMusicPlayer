
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


    public private(set) var state: PlaybackState = .idle
    public private(set) var currentURL: URL?
    public private(set) var sourceSampleRate: Double = 0
    public private(set) var sourceBitDepth: Int = 0
    public private(set) var sourceChannels: Int = 0

    public private(set) var duration: TimeInterval = 0
    public private(set) var currentTime: TimeInterval = 0

    public var volume: Float = 1.0 {
        didSet { engine.mainMixerNode.outputVolume = max(0, min(1, volume)) }
    }


    public private(set) var queue: [URL] = []
    public private(set) var currentIndex: Int? = nil

    public enum RepeatMode: String, CaseIterable { case off, one, all }
    public var repeatMode: RepeatMode = .off
    public var isShuffleEnabled: Bool = false {
        didSet {
            if isShuffleEnabled {
                rebuildShuffleOrder(startingAt: currentIndex)
            } else {
                shuffledIndices = []
                shuffleCursor = 0
            }
        }
    }

    private var shuffledIndices: [Int] = []
    private var shuffleCursor: Int = 0


    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var file: AVAudioFile?
    private var totalFrames: AVAudioFramePosition = 0
    private var seekOffsetFrames: AVAudioFramePosition = 0
    private var isFinishing = false
    private var scheduleGeneration: UInt64 = 0

    private var securityScopedURL: URL?
    private var positionTimer: Timer?
    /// seek 后短暂屏蔽 updateCurrentTime 的窗口，避免视觉回弹
    private var seekJustHappenedUntil: Date = .distantPast

    private static let log = Logger(subsystem: "app.neiro", category: "Engine")


    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = volume

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }


    public func load(url: URL) {
        stop()

        // Keep security scope alive during playback for sandboxed files.
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
            if !player.isPlaying {
                if player.engine != nil {
                    player.play()
                }
                if !player.isPlaying {
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
        if player.isPlaying {
            player.pause()
        }
        player.reset()
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

    public func nextTrack() {
        guard !queue.isEmpty, let cur = currentIndex else { return }
        let nextIdx = computeNextIndex(from: cur)
        guard let n = nextIdx else {
            stop()
            return
        }
        currentIndex = n
        load(url: queue[n])
    }

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
        if let s = startingAt, let pos = all.firstIndex(of: s) {
            all.swapAt(0, pos)
        }
        shuffledIndices = all
        shuffleCursor = 0
    }

    public func seek(toSeconds seconds: TimeInterval) {
        guard let f = file else { return }
        let wasPlaying = (state == .playing)
        let sr = f.processingFormat.sampleRate
        let safeUpperBound = max(0, duration - 0.05)
        let clamped = max(0, min(seconds, safeUpperBound))
        let frame = AVAudioFramePosition(clamped * sr)

        // 关键：用 stop() 替代 pause()+reset()。
        // reset() 只清待播 buffer，不归零 player.sampleTime，
            // 导致 updateCurrentTime 把旧 sampleTime 加进新位置 → 进度条立刻回弹到错误位置。
        // stop() 同时清 buffer 并归零 sampleTime。
        player.stop()

        // 立刻反映新位置，避免 timer 还没来得及更新前 UI 仍显示旧值
        currentTime = clamped
        // 暂时屏蔽 updateCurrentTime 几个 tick，等 player.play() 后 lastRenderTime 重置
        seekJustHappenedUntil = Date().addingTimeInterval(0.25)

        do {
            try startEngineIfNeeded()
            scheduleAndPlay(from: frame, autoPlay: wasPlaying)
            if wasPlaying { state = .playing } else { state = .paused }
        } catch {
            state = .error(error.localizedDescription)
        }
    }


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
        // Ignore stale completion callbacks from previous schedules.
        scheduleGeneration &+= 1
        let generation = scheduleGeneration

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
        // Avoid a synchronous stop on MainActor here to prevent QoS inversions.
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
        // seek 后 0.25s 内不要让 timer 覆盖 currentTime
        // 因为 player.play() 后 lastRenderTime 可能还反映旧 buffer 残留
        if Date() < seekJustHappenedUntil { return }

        guard let f = file,
              let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return
        }
        let sr = f.processingFormat.sampleRate
        // stop() 之后 sampleTime 从 0 重新计数，所以 elapsed = seekOffset + sampleTime
        let sampleSec = max(0, Double(playerTime.sampleTime) / playerTime.sampleRate)
        let elapsed = Double(seekOffsetFrames) / sr + sampleSec
        currentTime = max(0, min(elapsed, duration))
    }


    @objc private func handleConfigurationChange(_ note: Notification) {
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


    private func bitDepth(from format: AVAudioFormat) -> Int {
        guard let asbd = file?.fileFormat.streamDescription.pointee else { return 0 }
        if (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0 { return 32 }
        return Int(asbd.mBitsPerChannel)
    }
}
