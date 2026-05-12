//
//  SongsView.swift
//  Neiro
//

import SwiftUI
import SwiftData

struct SongsView: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Track.title)]) private var tracks: [Track]

    var body: some View {
        content
            .neiroPageBackground()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: NeiroText.tr("全部歌曲", "Songs"), count: tracks.count)

            if tracks.isEmpty {
                EmptyState(systemImage: "music.note", title: NeiroText.tr("媒体库还是空的", "Library is empty"),
                           subtitle: NeiroText.tr("按 ⌘O 打开导入窗口，把音乐拖进去", "Press ⌘O to open import and drop music"))
            } else {
                Table(tracks) {
                    TableColumn(NeiroText.tr("曲名", "Title")) { track in
                        HStack {
                            AlbumThumbnail(data: track.album?.artworkData, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).font(.body)
                                Text(track.artist?.name ?? NeiroText.tr("未知作曲家", "Unknown Artist"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            engine.load(url: track.fileURL)
                        }
                    }
                    TableColumn(NeiroText.tr("专辑", "Album")) { track in
                        Text(track.album?.name ?? "—").foregroundStyle(.secondary)
                    }
                    .width(min: 140, ideal: 220)
                    TableColumn(NeiroText.tr("时长", "Time")) { track in
                        Text(timeString(track.durationSeconds))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .width(60)
                    TableColumn(NeiroText.tr("格式", "Format")) { track in
                        formatBadge(track)
                    }
                    .width(120)
                    TableColumn("") { track in
                        Button {
                            LibraryActions.toggleFavorite(track, in: context)
                        } label: {
                            Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(track.isFavorite ? .pink : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.borderless)
                        .help(NeiroText.tr("喜爱", "Favorite"))
                    }
                    .width(40)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private func formatBadge(_ track: Track) -> some View {
        if track.sampleRate > 0 {
            let sr = String(format: "%.1f", track.sampleRate / 1000)
            let bits = track.bitDepth > 0 ? "\(track.bitDepth)bit" : ""
            Text([sr + "kHz", bits].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }

    private func timeString(_ s: TimeInterval) -> String {
        guard s.isFinite, s >= 0 else { return "—" }
        let total = Int(s)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
