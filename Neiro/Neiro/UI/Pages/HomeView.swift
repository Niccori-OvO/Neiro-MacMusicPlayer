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
        .neiroPageBackground()
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.largeTitle.bold())
            Text("Neiro · 你的本地音乐库")
                .foregroundStyle(.secondary)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "早安"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<23: return "晚上好"
        default:      return "夜深了"
        }
    }

    // MARK: - Daily picks

    private var dailyPicks: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("每日推荐").font(.title2.bold())
                Text(todayDateLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    if let first = picks.first {
                        engine.load(url: first.fileURL)
                    }
                } label: {
                    Label("播放", systemImage: "play.fill")
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
                .padding(.vertical, 4)
            }
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
            Text("媒体库").font(.title3.bold())
            HStack(spacing: 16) {
                Button { router.go(.songs) } label: {
                    StatCard(icon: "music.note", title: "歌曲", value: "\(tracks.count)")
                }
                .buttonStyle(.plain)
                .hoverLift()

                Button { router.go(.albums) } label: {
                    StatCard(icon: "square.stack", title: "专辑", value: "\(albums.count)")
                }
                .buttonStyle(.plain)
                .hoverLift()

                Button { router.go(.artists) } label: {
                    StatCard(icon: "person.2", title: "作曲家", value: "\(artists.count)")
                }
                .buttonStyle(.plain)
                .hoverLift()
            }
        }
    }

    // MARK: - Empty

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("还没有歌曲", systemImage: "exclamationmark.circle")
                .font(.headline)
            Text("把音乐文件或文件夹拖进「导入音乐」窗口即可加入媒体库。源文件留在原位置，Neiro 不会扫描其它任何路径。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                openWindow(id: "import")
            } label: {
                Label("打开导入窗口", systemImage: "tray.and.arrow.down")
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
                AlbumThumbnail(data: track.album?.artworkData, size: 140)
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
                Text(track.artist?.name ?? "未知作曲家")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
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
