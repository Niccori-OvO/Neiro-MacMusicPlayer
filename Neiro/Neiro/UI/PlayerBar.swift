
import SwiftUI
import SwiftData
import AppKit
import Carbon.HIToolbox

struct InlinePlayerBar: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query private var allTracks: [Track]

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    /// 松手后 0.3s 内 slider 显示用户拖到的位置，等 engine 回填精确值再切换
    @State private var seekTargetHoldUntil: Date = .distantPast
    @State private var showQueue = false
    @State private var showVolume = false
    @State private var lastRecordedTrackID: PersistentIdentifier? = nil
    @State private var seekHoldTask: Task<Void, Never>?
    @State private var mediaKeyMonitor: Any?

    var body: some View {
        @Bindable var engine = engine
        HStack(spacing: 12) {
            transportCluster
            Divider().frame(height: 28).opacity(0.4)
            nowPlayingCard
            Divider().frame(height: 28).opacity(0.4)
            rightCluster
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor.opacity(0.08))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .onAppear { installMediaKeyMonitorIfNeeded() }
        .onDisappear { uninstallMediaKeyMonitor() }
        .onChange(of: engine.currentURL) { _, _ in
            lastRecordedTrackID = nil
        }
        .onChange(of: engine.currentTime) { _, t in
            let threshold = min(30.0, max(15.0, engine.duration * 0.5))
            guard t >= threshold,
                  let track = currentTrack,
                  lastRecordedTrackID != track.persistentModelID else { return }
            LibraryActions.recordPlay(track, in: context)
            lastRecordedTrackID = track.persistentModelID
        }
    }


    private var transportCluster: some View {
        HStack(spacing: 10) {
            Button {
                engine.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(engine.isShuffleEnabled ? Color.accentColor : .secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(NeiroText.tr("随机播放", "Shuffle"))

            transportButton("backward.fill", size: 13) { previousOrRestartTrack() }
            .onLongPressGesture(minimumDuration: 0.22, pressing: { pressing in
                if pressing { startContinuousSeek(step: -2.5) } else { stopContinuousSeek() }
            }, perform: {})
            .disabled(engine.currentURL == nil)

            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.tint)
                    .frame(width: 30, height: 30)
                    .background(.regularMaterial, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isPlaying)
            }
            .buttonStyle(.plain)
            .disabled(engine.currentURL == nil)
            .keyboardShortcut(.space, modifiers: [])

            transportButton("forward.fill", size: 13) { nextTrack() }
            .onLongPressGesture(minimumDuration: 0.22, pressing: { pressing in
                if pressing { startContinuousSeek(step: 2.5) } else { stopContinuousSeek() }
            }, perform: {})
            .disabled(engine.currentURL == nil)

            Button {
                engine.cycleRepeatMode()
            } label: {
                Image(systemName: engine.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(engine.repeatMode == .off ? .secondary : Color.accentColor)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(NeiroText.tr("循环模式", "Repeat mode"))
        }
    }


    private var nowPlayingCard: some View {
        HStack(spacing: 10) {
            Button {
                if engine.currentURL != nil { router.presentNowPlaying() }
            } label: {
                HStack(spacing: 10) {
                    artworkThumb
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(displayTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            if currentTrack?.isFavorite == true {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.pink)
                            }
                        }
                        HStack(spacing: 6) {
                            Text(displayArtist)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .help(NeiroText.tr("打开播放详情", "Open Now Playing"))

            progressSlider
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var artworkThumb: some View {
        Group {
            if let data = currentTrack?.album?.artworkData,
               let img = NSImage(data: data) {
                Image(nsImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.accentColor.opacity(0.6), .accentColor.opacity(0.2)],
                                   startPoint: .top, endPoint: .bottom)
                    Image(systemName: "music.note").foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var progressSlider: some View {
        Slider(
            value: Binding(
                get: {
                    // 优先级：正在拖 > 刚松手保护期 > engine 真实时间
                    if isScrubbing { return scrubValue }
                    if Date() < seekTargetHoldUntil { return scrubValue }
                    return engine.currentTime
                },
                set: { newVal in
                    scrubValue = newVal
                    isScrubbing = true
                }),
            in: 0...max(engine.duration, 0.01),
            onEditingChanged: { editing in
                if editing {
                    isScrubbing = true
                } else {
                    // 松开：跳转 + 进入 300ms 保护期，期间 slider 显示 scrubValue 不被 engine.currentTime 覆盖
                    engine.seek(toSeconds: scrubValue)
                    seekTargetHoldUntil = Date().addingTimeInterval(0.3)
                    isScrubbing = false
                }
            }
        )
        .controlSize(.mini)
        .disabled(engine.currentURL == nil)
    }


    @ViewBuilder
    private var rightCluster: some View {
        @Bindable var engine = engine
        HStack(spacing: 8) {
            Button {
                if let t = currentTrack {
                    LibraryActions.toggleFavorite(t, in: context)
                }
            } label: {
                Image(systemName: (currentTrack?.isFavorite ?? false) ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle((currentTrack?.isFavorite ?? false) ? .pink : .secondary)
                    .frame(width: 26, height: 26)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(currentTrack == nil)
            .help(NeiroText.tr("喜爱", "Favorite"))

            Button {
                router.toggleLyrics()
            } label: {
                Image(systemName: "text.bubble")
                    .font(.system(size: 13, weight: .medium))
                    .symbolVariant(router.isLyricsPresented ? .fill : .none)
                    .foregroundStyle(router.isLyricsPresented ? Color.accentColor : .primary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(NeiroText.tr("歌词", "Lyrics"))

            Button {
                showQueue.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(NeiroText.tr("当前播放", "Now Playing Queue"))
            .popover(isPresented: $showQueue, arrowEdge: .top) {
                QueuePopover()
            }

            Button {
                showVolume.toggle()
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(NeiroText.tr("音量", "Volume"))
            .popover(isPresented: $showVolume, arrowEdge: .top) {
                VStack(spacing: 8) {
                    Slider(value: $engine.volume, in: 0...1)
                        .frame(width: 160)
                    Text("\(Int(engine.volume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
        }
    }


    private var isPlaying: Bool { engine.state == .playing }

    private var currentTrack: Track? {
        guard let url = engine.currentURL else { return nil }
        return allTracks.first(where: { $0.matches(url: url) })
    }

    private var displayTitle: String {
        if let t = currentTrack?.title, !t.isEmpty { return t }
        guard let url = engine.currentURL else { return NeiroText.tr("没有曲目", "No Track") }
        let raw = url.deletingPathExtension().lastPathComponent
        return raw.removingPercentEncoding ?? raw
    }

    private var displayArtist: String {
        if let name = currentTrack?.artist?.name, !name.isEmpty { return name }
        if engine.currentURL != nil { return NeiroText.tr("未知作曲家", "Unknown Artist") }
        return ""
    }

    private func togglePlayPause() {
        switch engine.state {
        case .playing: engine.pause()
        case .paused: engine.play()
        case .idle, .error:
            if let url = engine.currentURL { engine.load(url: url) }
        }
    }

    private func transportButton(_ name: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .medium))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
    }

    private var sortedTracks: [Track] {
        allTracks.sorted { $0.filePath.localizedStandardCompare($1.filePath) == .orderedAscending }
    }

    private func previousOrRestartTrack() {
        if !engine.queue.isEmpty, engine.currentIndex != nil {
            engine.previousTrack()
            return
        }
        guard let currentURL = engine.currentURL else { return }
        if engine.currentTime > 3 {
            engine.seek(toSeconds: 0)
            return
        }
        guard let idx = sortedTracks.firstIndex(where: { $0.filePath == currentURL.path }) else {
            engine.seek(toSeconds: 0)
            return
        }
        let previousIndex = max(0, idx - 1)
        let track = sortedTracks[previousIndex]
        engine.load(url: URL(fileURLWithPath: track.filePath))
    }

    private func nextTrack() {
        if !engine.queue.isEmpty, engine.currentIndex != nil {
            engine.nextTrack()
            return
        }
        guard let currentURL = engine.currentURL else { return }
        guard let idx = sortedTracks.firstIndex(where: { $0.filePath == currentURL.path }) else { return }
        let nextIndex = min(sortedTracks.count - 1, idx + 1)
        guard nextIndex != idx else { return }
        let track = sortedTracks[nextIndex]
        engine.load(url: URL(fileURLWithPath: track.filePath))
    }

    private func startContinuousSeek(step: TimeInterval) {
        stopContinuousSeek()
        seekHoldTask = Task { @MainActor in
            while !Task.isCancelled {
                let target = min(max(0, engine.duration - 0.05), max(0, engine.currentTime + step))
                engine.seek(toSeconds: target)
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    private func stopContinuousSeek() {
        seekHoldTask?.cancel()
        seekHoldTask = nil
    }

    private func installMediaKeyMonitorIfNeeded() {
        guard mediaKeyMonitor == nil else { return }
        mediaKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { event in
            guard event.subtype.rawValue == 8 else { return event }
            let keyCode = ((event.data1 & 0xFFFF0000) >> 16)
            let keyFlags = (event.data1 & 0x0000FFFF)
            let isKeyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A
            guard isKeyDown else { return event }

            switch Int32(keyCode) {
            case NX_KEYTYPE_PLAY:
                togglePlayPause()
                return nil
            case NX_KEYTYPE_FAST:
                nextTrack()
                return nil
            case NX_KEYTYPE_REWIND:
                previousOrRestartTrack()
                return nil
            default:
                return event
            }
        }
    }

    private func uninstallMediaKeyMonitor() {
        if let monitor = mediaKeyMonitor {
            NSEvent.removeMonitor(monitor)
            mediaKeyMonitor = nil
        }
    }
}


private struct QueuePopover: View {
    @Environment(AudioEngine.self) private var engine
    @Query private var allTracks: [Track]

    private var currentTrack: Track? {
        guard let url = engine.currentURL else { return nil }
        return allTracks.first(where: { $0.matches(url: url) })
    }

    private func upcomingTracks() -> [URL] {
        guard let cur = engine.currentIndex, cur < engine.queue.count - 1 else { return [] }
        return Array(engine.queue[(cur + 1)...])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NeiroText.tr("当前播放", "Now Playing")).font(.headline)
                Spacer()
            }

            if let t = currentTrack {
                HStack(spacing: 10) {
                    AlbumThumbnail(data: t.album?.artworkData, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(t.artist?.name ?? NeiroText.tr("未知作曲家", "Unknown Artist"))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if let url = engine.currentURL {
                Text(url.lastPathComponent).font(.callout).foregroundStyle(.secondary)
            } else {
                Text(NeiroText.tr("没有正在播放的曲目", "Nothing is playing")).font(.callout).foregroundStyle(.secondary)
            }

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(NeiroText.tr("接下来", "Up Next")).font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    if engine.queue.count > 1 {
                        Text("\(engine.queue.count) " + NeiroText.tr("首", "tracks"))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }

                if engine.queue.isEmpty {
                    Text(NeiroText.tr("队列为空", "Queue is empty"))
                        .font(.caption).foregroundStyle(.tertiary)
                } else {
                    let upcoming = upcomingTracks()
                    if upcoming.isEmpty {
                        Text(NeiroText.tr("已经是最后一首", "End of queue"))
                            .font(.caption).foregroundStyle(.tertiary)
                    } else {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(upcoming.prefix(10), id: \.absoluteString) { url in
                                    QueueRow(url: url)
                                }
                                if upcoming.count > 10 {
                                    Text("… +\(upcoming.count - 10)")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}

private struct QueueRow: View {
    let url: URL
    @Query private var allTracks: [Track]

    private var track: Track? {
        allTracks.first(where: { $0.filePath == url.path })
    }

    var body: some View {
        HStack(spacing: 8) {
            AlbumThumbnail(data: track?.album?.artworkData, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(track?.title ?? url.deletingPathExtension().lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                if let artist = track?.artist?.name {
                    Text(artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
