//
//  HomeView.swift
//  Neiro
//
//  欢迎 + 每日推荐 + 库容统计。
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(LibraryService.self) private var library
    @Environment(AudioEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.openWindow) private var openWindow
    @Query private var tracks: [Track]
    @Query private var albums: [Album]
    @Query private var artists: [Artist]
    @AppStorage(NeiroTheme.homeSubtitleKey) private var homeSubtitle: String = NeiroTheme.defaultHomeSubtitle
    @AppStorage(NeiroTheme.languageKey) private var languageRaw: String = NeiroLanguage.chinese.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                if !tracks.isEmpty {
                    dailyPicks
                }
                stats
                if tracks.isEmpty { emptyHint }
            }
            .padding(28)
            .padding(.trailing, 8)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.largeTitle.bold())
            Text(homeSubtitle)
                .foregroundStyle(.secondary)
        }
    }

    private var greeting: String {
        let language = NeiroLanguage(rawValue: languageRaw) ?? .chinese
        let hour = Calendar.current.component(.hour, from: Date())
        if language == .english {
            switch hour {
            case 5..<11:  return "Good morning"
            case 11..<14: return "Good noon"
            case 14..<18: return "Good afternoon"
            case 18..<23: return "Good evening"
            default:      return "Late night"
            }
        } else {
            switch hour {
            case 5..<11:  return "早安"
            case 11..<14: return "中午好"
            case 14..<18: return "下午好"
            case 18..<23: return "晚上好"
            default:      return "夜深了"
            }
        }
    }

    // MARK: - Daily picks

    private var dailyPicks: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(NeiroText.tr("每日推荐", "Daily Picks")).font(.title2.bold())
                Text(todayDateLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    if let first = picks.first {
                        engine.load(url: first.fileURL)
                    }
                } label: {
                    Label(NeiroText.tr("播放", "Play"), systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(picks.isEmpty)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(picks) { track in
                        DailyPickCard(track: track) {
                            engine.load(url: track.fileURL)
                        }
                        .hoverLift()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
        }
    }

    private var todayDateLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MM-dd"
        return df.string(from: Date())
    }

    /// 每天用今日日期作 seed 推 6 首。当库小于 6 时全选。
    private var picks: [Track] {
        guard !tracks.isEmpty else { return [] }
        let seed = todaySeed()
        var generator = SeededGenerator(seed: seed)
        let shuffled = tracks.shuffled(using: &generator)
        return Array(shuffled.prefix(6))
    }

    private func todaySeed() -> UInt64 {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let raw = (comps.year ?? 0) * 10000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
        return UInt64(bitPattern: Int64(raw))
    }

    // MARK: - Stats

    private var stats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NeiroText.tr("媒体库", "Library")).font(.title3.bold())
            HStack(spacing: 16) {
                Button { router.go(.songs) } label: {
                    StatCard(icon: "music.note", title: NeiroText.tr("歌曲", "Songs"), value: "\(tracks.count)")
                }
                .buttonStyle(.plain)
                .hoverLift()

                Button { router.go(.albums) } label: {
                    StatCard(icon: "square.stack", title: NeiroText.tr("专辑", "Albums"), value: "\(albums.count)")
                }
                .buttonStyle(.plain)
                .hoverLift()

                Button { router.go(.artists) } label: {
                    StatCard(icon: "person.2", title: NeiroText.tr("作曲家", "Artists"), value: "\(artists.count)")
                }
                .buttonStyle(.plain)
                .hoverLift()
            }
        }
    }

    // MARK: - Empty

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NeiroText.tr("还没有歌曲", "No songs yet"), systemImage: "exclamationmark.circle")
                .font(.headline)
            Text(NeiroText.tr("把音乐文件或文件夹拖进「导入音乐」窗口即可加入媒体库。源文件留在原位置，Neiro 不会扫描其它任何路径。", "Drag music files or folders into Import Music to add them. Source files stay where they are; Neiro scans nothing else."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                openWindow(id: "import")
            } label: {
                Label(NeiroText.tr("打开导入窗口", "Open Import Window"), systemImage: "tray.and.arrow.down")
            }
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: [.command])
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neiroCard()
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.bold().monospacedDigit())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neiroCard()
    }
}

// MARK: - Daily pick card

private struct DailyPickCard: View {
    let track: Track
    var onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    DailyPickArtwork(data: track.album?.artworkData, size: 132)
                }
                .frame(width: 140, height: 140)
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
                Text(track.artist?.name ?? NeiroText.tr("未知作曲家", "Unknown Artist"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DailyPickArtwork: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.20))

            if let data, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.accentColor.opacity(0.45), .accentColor.opacity(0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.36, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Seeded RNG（每天稳定）

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xdeadbeef : seed }

    mutating func next() -> UInt64 {
        // splitmix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}
