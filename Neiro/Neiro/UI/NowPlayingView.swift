//
//  NowPlayingView.swift
//  Neiro
//
//  全屏播放页：大封面 + 模糊背景 + 标题 + 进度 + 控件 + 喜爱。
//  从 PlayerBar 点封面 / 标题区进入；左上角 chevron.down 收起。
//

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

    var body: some View {
        @Bindable var engine = engine
        ZStack {
            background
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Background

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

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 28) {
            topBar
            Spacer(minLength: 0)
            artwork
            titleBlock
            progress
            controls
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 32)
    }

    private var topBar: some View {
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

            Spacer()

            Button {
                router.toggleLyrics()
            } label: {
                Image(systemName: "text.bubble")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(engine.currentURL == nil)
            .help("歌词")
        }
    }

    private var artwork: some View {
        Group {
            if let data = currentTrack?.album?.artworkData,
               let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 320, height: 320)
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
                .frame(width: 320, height: 320)
                .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
            }
        }
        .scaleEffect(isPlaying ? 1.0 : 0.94)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isPlaying)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(displayTitle)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(currentTrack?.artist?.name ?? "未知作曲家")
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let album = currentTrack?.album?.name {
                Text(album)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 540)
    }

    private var progress: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : engine.currentTime },
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
                        isScrubbing = false
                    }
                }
            )
            .disabled(engine.currentURL == nil)

            HStack {
                Text(timeString(isScrubbing ? scrubValue : engine.currentTime))
                Spacer()
                Text(timeString(engine.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 540)
    }

    private var controls: some View {
        HStack(spacing: 40) {
            iconButton("gobackward.10", size: 28) {
                engine.seek(toSeconds: max(0, engine.currentTime - 10))
            }
            .disabled(engine.currentURL == nil)

            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isPlaying)
            }
            .buttonStyle(.plain)
            .disabled(engine.currentURL == nil)

            iconButton("goforward.10", size: 28) {
                engine.seek(toSeconds: min(engine.duration, engine.currentTime + 10))
            }
            .disabled(engine.currentURL == nil)

            Spacer().frame(width: 4)

            Button {
                if let t = currentTrack {
                    LibraryActions.toggleFavorite(t, in: context)
                }
            } label: {
                Image(systemName: (currentTrack?.isFavorite ?? false) ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundStyle((currentTrack?.isFavorite ?? false) ? .pink : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(currentTrack == nil)
            .help("喜爱")
        }
    }

    // MARK: - Helpers

    private var isPlaying: Bool { engine.state == .playing }

    private var currentTrack: Track? {
        guard let path = engine.currentURL?.path else { return nil }
        return allTracks.first(where: { $0.filePath == path })
    }

    private var displayTitle: String {
        if let t = currentTrack?.title, !t.isEmpty { return t }
        return engine.currentURL?.deletingPathExtension().lastPathComponent ?? "没有曲目"
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
