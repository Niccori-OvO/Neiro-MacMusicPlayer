//
//  PlayerBar.swift
//  Neiro
//
//  贯穿底部的播放栏。三栏布局：
//    左：播放控件（上一首 / 播放暂停 / 下一首）
//    中：封面 + 曲名 + 作曲家 + 进度
//    右：音量 + 占位按钮（歌词 / 队列，Phase 2~3）
//

import SwiftUI
import SwiftData

struct PlayerBar: View {
    @Environment(AudioEngine.self) private var engine
    @Query private var allTracks: [Track]
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        @Bindable var engine = engine
        HStack(spacing: 16) {
            transportControls
            middleSection
            rightControls
        }
        .frame(height: 64)
    }

    // MARK: - Transport (left)

    private var transportControls: some View {
        HStack(spacing: 14) {
            iconButton("backward.fill") {
                // Phase 2：上一首；Phase 1 直接跳到曲首
                engine.seek(toSeconds: 0)
            }

            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isPlaying)
            }
            .buttonStyle(.plain)
            .pressDown()
            .disabled(engine.currentURL == nil)
            .keyboardShortcut(.space, modifiers: [])

            iconButton("forward.fill") {
                // Phase 2：下一首；Phase 1 直接跳到曲尾让其自然结束
                engine.seek(toSeconds: max(0, engine.duration - 0.2))
            }
        }
        .frame(width: 140, alignment: .leading)
    }

    // MARK: - Middle (artwork + info + progress)

    private var middleSection: some View {
        HStack(spacing: 12) {
            artworkThumb

            VStack(alignment: .leading, spacing: 4) {
                titleLine

                progressSlider

                HStack {
                    Text(timeString(isScrubbing ? scrubValue : engine.currentTime))
                    Spacer()
                    Text(formatLine).lineLimit(1)
                    Spacer()
                    Text(timeString(engine.duration))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleLine: some View {
        HStack(spacing: 6) {
            Text(displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            if let artist = currentTrack?.artist?.name {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var artworkThumb: some View {
        Group {
            if let data = currentTrack?.album?.artworkData,
               let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(radius: 2, y: 1)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.accentColor.opacity(0.5), .accentColor.opacity(0.15)],
                            startPoint: .top, endPoint: .bottom))
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.title3)
                }
                .frame(width: 44, height: 44)
                .shadow(radius: 2, y: 1)
            }
        }
        .scaleEffect(isPlaying ? 1.0 : 0.92)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPlaying)
        .animation(.easeInOut(duration: 0.25), value: currentTrack?.id)
    }

    private var progressSlider: some View {
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
        .controlSize(.mini)
        .disabled(engine.currentURL == nil)
    }

    // MARK: - Right (volume + placeholders)

    @ViewBuilder
    private var rightControls: some View {
        @Bindable var engine = engine
        HStack(spacing: 12) {
            iconButton("text.bubble") {
                // Phase 3：歌词
            }
            .help("歌词（Phase 3）")
            .disabled(true)

            iconButton("list.bullet") {
                // Phase 2：播放队列
            }
            .help("播放队列（Phase 2）")
            .disabled(true)

            HStack(spacing: 6) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Slider(value: $engine.volume, in: 0...1)
                    .frame(width: 90)
                    .controlSize(.mini)
            }
        }
        .frame(width: 220, alignment: .trailing)
    }

    // MARK: - Helpers

    private var isPlaying: Bool { engine.state == .playing }

    /// 用当前 URL.path 在 SwiftData 里查曲目，找到就拿到 album / artist。
    private var currentTrack: Track? {
        guard let path = engine.currentURL?.path else { return nil }
        return allTracks.first(where: { $0.filePath == path })
    }

    private var displayTitle: String {
        if let title = currentTrack?.title, !title.isEmpty { return title }
        return engine.currentURL?.deletingPathExtension().lastPathComponent ?? "没有曲目"
    }

    private var formatLine: String {
        guard engine.sourceSampleRate > 0 else { return "" }
        let sr = String(format: "%.1f", engine.sourceSampleRate / 1000)
        let bits = engine.sourceBitDepth > 0 ? "\(engine.sourceBitDepth)bit" : ""
        return [sr + "kHz", bits].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func togglePlayPause() {
        switch engine.state {
        case .playing: engine.pause()
        case .paused: engine.play()
        case .idle, .error:
            if let url = engine.currentURL { engine.load(url: url) }
        }
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
    }

    private func timeString(_ s: TimeInterval) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let total = Int(s)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
