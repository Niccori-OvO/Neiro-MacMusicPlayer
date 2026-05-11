//
//  SongsView.swift
//  Neiro
//

import SwiftUI
import SwiftData

struct SongsView: View {
    @Environment(AudioEngine.self) private var engine
    @Query(sort: [SortDescriptor(\Track.title)]) private var tracks: [Track]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "全部歌曲", count: tracks.count)

            if tracks.isEmpty {
                EmptyState(systemImage: "music.note", title: "媒体库还是空的",
                           subtitle: "按 ⌘O 打开导入窗口，把音乐拖进去")
            } else {
                Table(tracks) {
                    TableColumn("曲名") { track in
                        HStack {
                            AlbumThumbnail(data: track.album?.artworkData, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).font(.body)
                                Text(track.artist?.name ?? "未知作曲家")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            engine.load(url: track.fileURL)
                        }
                    }
                    TableColumn("专辑") { track in
                        Text(track.album?.name ?? "—").foregroundStyle(.secondary)
                    }
                    .width(min: 140, ideal: 220)
                    TableColumn("时长") { track in
                        Text(timeString(track.durationSeconds))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .width(60)
                    TableColumn("格式") { track in
                        formatBadge(track)
                    }
                    .width(120)
                }
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
