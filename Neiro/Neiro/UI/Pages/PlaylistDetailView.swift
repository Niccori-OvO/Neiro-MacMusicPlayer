//
//  PlaylistDetailView.swift
//  Neiro
//
//  单个 playlist 详情。userCreated 类型可以「添加歌曲」（Phase 2）。
//

import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    let playlistID: UUID
    @Environment(AudioEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Query private var allPlaylists: [Playlist]
    @State private var showAddSheet = false

    private var playlist: Playlist? {
        allPlaylists.first(where: { $0.id == playlistID })
    }

    var body: some View {
        content
            .neiroPageBackground()
            .sheet(isPresented: $showAddSheet) {
                if let pl = playlist {
                    AddTracksSheet(playlist: pl)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let pl = playlist {
            VStack(alignment: .leading, spacing: 16) {
                header(pl)

                if pl.tracks.isEmpty {
                    EmptyState(
                        systemImage: "music.note.list",
                        title: NeiroText.tr("这个播放列表还是空的", "This playlist is empty"),
                        subtitle: pl.kind == .userCreated
                            ? NeiroText.tr("点击右上「添加歌曲」从媒体库挑选", "Click Add Songs in the top-right to pick tracks")
                            : NeiroText.tr("喜爱歌曲后会自动出现在这里", "Favorited songs will appear here automatically")
                    )
                } else {
                    tracksList(pl)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            EmptyState(systemImage: "questionmark.circle",
                       title: NeiroText.tr("找不到这个播放列表", "Playlist not found"),
                       subtitle: nil)
        }
    }

    private func header(_ pl: Playlist) -> some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: gradient(for: pl.kind),
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: icon(for: pl.kind))
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 160, height: 160)
            .shadow(radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(badgeText(for: pl.kind))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(pl.name)
                    .font(.largeTitle.bold())
                Text(NeiroText.tr("\(pl.tracks.count) 首歌", "\(pl.tracks.count) songs"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if pl.kind == .userCreated {
                Button {
                    showAddSheet = true
                } label: {
                    Label(NeiroText.tr("添加歌曲", "Add Songs"), systemImage: "plus")
                }
                .controlSize(.large)
            }
        }
    }

    @ViewBuilder
    private func tracksList(_ pl: Playlist) -> some View {
        Table(pl.tracks) {
            TableColumn(NeiroText.tr("曲名", "Title")) { t in
                HStack {
                    AlbumThumbnail(data: t.album?.artworkData, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.title)
                        Text(t.artist?.name ?? NeiroText.tr("未知作曲家", "Unknown Artist"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { engine.load(url: t.fileURL) }
            }
            TableColumn(NeiroText.tr("专辑", "Album")) { t in
                Text(t.album?.name ?? "—").foregroundStyle(.secondary)
            }
            .width(min: 140, ideal: 220)
            TableColumn(NeiroText.tr("时长", "Time")) { t in
                Text(timeString(t.durationSeconds))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(60)
            TableColumn("") { t in
                if pl.kind == .userCreated {
                    Button {
                        remove(track: t, from: pl)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(NeiroText.tr("从此 playlist 移除", "Remove from this playlist"))
                } else {
                    Button {
                        LibraryActions.toggleFavorite(t, in: context)
                    } label: {
                        Image(systemName: t.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(t.isFavorite ? .pink : .secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .width(40)
        }
        .scrollContentBackground(.hidden)
    }

    private func remove(track: Track, from pl: Playlist) {
        pl.tracks.removeAll { $0.id == track.id }
        try? context.save()
    }

    private func timeString(_ s: TimeInterval) -> String {
        guard s.isFinite, s >= 0 else { return "—" }
        let total = Int(s)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Kind helpers

    private func icon(for kind: Playlist.Kind) -> String {
        switch kind {
        case .favoriteTracks:  "heart.fill"
        case .favoriteAlbums:  "square.stack.fill"
        case .favoriteArtists: "star.fill"
        case .anime:           "sparkles"
        case .userCreated:     "music.note.list"
        }
    }

    private func badgeText(for kind: Playlist.Kind) -> String {
        switch kind {
        case .favoriteTracks:  NeiroText.tr("默认 · 喜爱", "Default · Favorites")
        case .favoriteAlbums:  NeiroText.tr("默认 · 专辑", "Default · Albums")
        case .favoriteArtists: NeiroText.tr("默认 · 作曲家", "Default · Artists")
        case .anime:           NeiroText.tr("默认 · 二次元企划", "Default · Anime")
        case .userCreated:     NeiroText.tr("自建", "Custom")
        }
    }

    private func gradient(for kind: Playlist.Kind) -> [Color] {
        switch kind {
        case .favoriteTracks:  [Color(red: 1, green: 0.45, blue: 0.55), Color(red: 1, green: 0.71, blue: 0.83)]
        case .favoriteAlbums:  [Color(red: 0.45, green: 0.55, blue: 1), Color(red: 0.75, green: 0.65, blue: 0.93)]
        case .favoriteArtists: [Color(red: 1, green: 0.75, blue: 0.30), Color(red: 1, green: 0.55, blue: 0.42)]
        case .anime:           [Color(red: 0.78, green: 0.55, blue: 0.95), Color(red: 1.00, green: 0.71, blue: 0.83)]
        case .userCreated:     [.accentColor.opacity(0.7), .accentColor.opacity(0.35)]
        }
    }
}

// MARK: - Add tracks sheet

private struct AddTracksSheet: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Track.title)]) private var allTracks: [Track]
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var query = ""

    private var existingIDs: Set<PersistentIdentifier> {
        Set(playlist.tracks.map(\.persistentModelID))
    }

    private var filteredTracks: [Track] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pool = allTracks.filter { !existingIDs.contains($0.persistentModelID) }
        guard !q.isEmpty else { return pool }
        return pool.filter {
            $0.title.lowercased().contains(q)
            || ($0.artist?.name.lowercased().contains(q) ?? false)
            || ($0.album?.name.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if filteredTracks.isEmpty {
                EmptyState(
                    systemImage: existingIDs.count == allTracks.count
                        ? "checkmark.circle"
                        : "magnifyingglass",
                    title: existingIDs.count == allTracks.count
                        ? NeiroText.tr("媒体库里所有歌都已在这个播放列表里", "All songs are already in this playlist")
                        : NeiroText.tr("没有匹配的曲目", "No matching songs"),
                    subtitle: nil
                )
            } else {
                List(filteredTracks, selection: $selectedIDs) { t in
                    HStack {
                        AlbumThumbnail(data: t.album?.artworkData, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.title)
                            Text(t.artist?.name ?? NeiroText.tr("未知作曲家", "Unknown Artist"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(t.album?.name ?? "")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .tag(t.persistentModelID)
                }
                .listStyle(.inset)
                .frame(minHeight: 320)
            }

            Divider()
            footer
        }
        .frame(width: 620, height: 540)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(NeiroText.tr("添加到", "Add to")) 「\(playlist.name)」").font(.headline)
                Spacer()
                Text(NeiroText.tr("已选 \(selectedIDs.count)", "Selected \(selectedIDs.count)"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            TextField(NeiroText.tr("搜索曲名 / 作曲家 / 专辑", "Search title / artist / album"), text: $query)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(NeiroText.tr("取消", "Cancel")) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(NeiroText.tr("添加", "Add")) { commit() }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIDs.isEmpty)
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private func commit() {
        for id in selectedIDs {
            if let track = allTracks.first(where: { $0.persistentModelID == id }),
               !playlist.tracks.contains(where: { $0.id == track.id }) {
                playlist.tracks.append(track)
            }
        }
        try? context.save()
        dismiss()
    }
}
