
import SwiftUI
import SwiftData
import AppKit

struct NowPlayingView: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query private var allTracks: [Track]

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var seekTargetHoldUntil: Date = .distantPast

    var body: some View {
        @Bindable var engine = engine
        ZStack {
            background
                .contentShape(Rectangle())
                .onTapGesture {
                    router.dismissNowPlaying()
                }
            content
                .allowsHitTesting(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }


    private var background: some View {
        Group {
            if let data = currentTrack?.album?.artworkData,
               let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 80)
                    .opacity(0.85)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [.accentColor.opacity(0.7), .accentColor.opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        }
        .overlay(.ultraThinMaterial)
        .ignoresSafeArea()
    }


    private var content: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let containerWidth = min(geo.size.width * 0.84, 900)
            let artworkSize = min(max(side * 0.24, 220), 380)
            let titleSize = min(max(side * 0.030, 22), 34)
            let progressWidth = min(max(containerWidth * 0.78, 380), 620)
            let topPad = max(16, geo.safeAreaInsets.top + 6)
            let controlSize = min(max(side * 0.018, 20), 26)

            ZStack(alignment: .topLeading) {
                VStack(spacing: max(12, side * 0.015)) {
                    Spacer(minLength: 0)
                    artwork(size: artworkSize)
                    titleBlock(titleSize: titleSize)
                    progress(width: progressWidth)
                    controls(controlSize: controlSize)
                    Spacer(minLength: 0)
                }
                .frame(width: containerWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, max(24, geo.size.width * 0.035))
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 8))

                topBar(topPadding: topPad)
                    .padding(.leading, 8)
            }
        }
    }

    private func topBar(topPadding: CGFloat) -> some View {
        HStack {
            Button {
                router.dismissNowPlaying()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help(NeiroText.tr("收起", "Collapse"))
            Spacer()
        }
        .padding(.top, topPadding)
    }

    private func artwork(size: CGFloat) -> some View {
        Group {
            if let data = currentTrack?.album?.artworkData,
               let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.accentColor.opacity(0.7), .accentColor.opacity(0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "music.note")
                        .font(.system(size: 80, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
            }
        }
        .scaleEffect(isPlaying ? 1.0 : 0.94)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isPlaying)
    }

    private func titleBlock(titleSize: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text(displayTitle)
                .font(.system(size: titleSize, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(currentTrack?.artist?.name ?? NeiroText.tr("未知作曲家", "Unknown Artist"))
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let album = currentTrack?.album?.name {
                Text(album)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 580)
    }

    private func progress(width: CGFloat) -> some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: {
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
                        engine.seek(toSeconds: scrubValue)
                        seekTargetHoldUntil = Date().addingTimeInterval(0.3)
                        isScrubbing = false
                    }
                }
            )
            .disabled(engine.currentURL == nil)

            HStack {
                Text(timeString({
                    if isScrubbing { return scrubValue }
                    if Date() < seekTargetHoldUntil { return scrubValue }
                    return engine.currentTime
                }()))
                Spacer()
                Text(timeString(engine.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .frame(width: width)
    }

    private func controls(controlSize: CGFloat) -> some View {
        HStack(spacing: 32) {
            Button {
                if let t = currentTrack {
                    LibraryActions.toggleFavorite(t, in: context)
                }
            } label: {
                Image(systemName: (currentTrack?.isFavorite ?? false) ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundStyle((currentTrack?.isFavorite ?? false) ? .pink : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(currentTrack == nil)
            .help(NeiroText.tr("喜爱", "Favorite"))

            iconButton("gobackward.10", size: controlSize) {
                engine.seek(toSeconds: max(0, engine.currentTime - 10))
            }
            .disabled(engine.currentURL == nil)

            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: controlSize * 2.35))
                    .foregroundStyle(.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isPlaying)
            }
            .buttonStyle(.plain)
            .disabled(engine.currentURL == nil)

            iconButton("goforward.10", size: controlSize) {
                let target = min(max(0, engine.duration - 0.05), engine.currentTime + 10)
                engine.seek(toSeconds: target)
            }
            .disabled(engine.currentURL == nil)

            Image(systemName: "heart")
                .font(.system(size: 22))
                .opacity(0)
        }
    }


    private var isPlaying: Bool { engine.state == .playing }

    private var currentTrack: Track? {
        guard let url = engine.currentURL else { return nil }
        return allTracks.first(where: { $0.matches(url: url) })
    }

    private var displayTitle: String {
        if let t = currentTrack?.title, !t.isEmpty { return t }
        return engine.currentURL?.deletingPathExtension().lastPathComponent ?? NeiroText.tr("没有曲目", "No Track")
    }

    private func togglePlayPause() {
        switch engine.state {
        case .playing: engine.pause()
        case .paused: engine.play()
        case .idle, .error:
            if let url = engine.currentURL { engine.load(url: url) }
        }
    }

    private func iconButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ s: TimeInterval) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let total = Int(s)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
