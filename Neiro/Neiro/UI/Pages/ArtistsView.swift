//
//  ArtistsView.swift
//  Neiro
//

import SwiftUI
import SwiftData

struct ArtistsView: View {
    @Environment(AudioEngine.self) private var engine
    @Query(sort: \Artist.name) private var artists: [Artist]
    @State private var selected: Artist?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "作曲家", count: artists.count)

            if artists.isEmpty {
                EmptyState(systemImage: "person.2", title: "暂无作曲家", subtitle: "导入音乐后会自动归类")
            } else {
                List(selection: $selected) {
                    ForEach(artists) { artist in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist.name).font(.body)
                                Text("\(artist.tracks.count) 首")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .tag(artist)
                    }
                }
            }
        }
        .padding(20)
        .sheet(item: $selected) { artist in
            ArtistDetailSheet(artist: artist)
        }
    }
}

private struct ArtistDetailSheet: View {
    let artist: Artist
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(artist.name).font(.title.bold())
                Spacer()
            }
            Text("\(artist.tracks.count) 首歌").foregroundStyle(.secondary)
            Divider()
            Table(artist.tracks.sorted { $0.title < $1.title }) {
                TableColumn("曲名") { t in
                    Text(t.title)
                        .onTapGesture(count: 2) { engine.load(url: t.fileURL) }
                }
                TableColumn("专辑") { t in
                    Text(t.album?.name ?? "—").foregroundStyle(.secondary)
                }
                TableColumn("时长") { t in
                    Text(format(seconds: t.durationSeconds))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }.width(60)
            }
        }
        .padding(20)
        .frame(width: 600, height: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }

    private func format(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
