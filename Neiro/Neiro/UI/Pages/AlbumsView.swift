//
//  AlbumsView.swift
//  Neiro
//

import SwiftUI
import SwiftData

struct AlbumsView: View {
    @Environment(AudioEngine.self) private var engine
    @Query(sort: [SortDescriptor(\Album.name)]) private var albums: [Album]
    @State private var selectedAlbum: Album?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        content
            .neiroPageBackground()
            .sheet(item: $selectedAlbum) { album in
                AlbumDetailSheet(album: album)
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "专辑", count: albums.count)

            if albums.isEmpty {
                EmptyState(systemImage: "square.stack",
                           title: "还没有专辑",
                           subtitle: "导入音乐后会自动按专辑归类")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(albums) { album in
                            AlbumCard(album: album)
                                .hoverLift()
                                .onTapGesture { selectedAlbum = album }
                        }
                    }
                    .padding(.top, 4)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .padding(20)
    }
}

struct AlbumCard: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AlbumThumbnail(data: album.artworkData, size: 160)
            Text(album.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(album.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}

private struct AlbumDetailSheet: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                AlbumThumbnail(data: album.artworkData, size: 120)
                VStack(alignment: .leading, spacing: 6) {
                    Text(album.name).font(.title2.bold())
                    Text(album.artistName).foregroundStyle(.secondary)
                    if let y = album.year { Text("\(y)").foregroundStyle(.tertiary) }
                    Text("\(album.tracks.count) 首")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            Table(album.tracks.sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }) {
                TableColumn("#") { t in
                    Text("\(t.trackNumber ?? 0)").foregroundStyle(.secondary)
                }.width(30)
                TableColumn("曲名") { t in
                    Text(t.title)
                        .onTapGesture(count: 2) { engine.load(url: t.fileURL) }
                }
                TableColumn("时长") { t in
                    Text(format(seconds: t.durationSeconds))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }.width(60)
            }
        }
        .padding(20)
        .frame(width: 560, height: 480)
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
