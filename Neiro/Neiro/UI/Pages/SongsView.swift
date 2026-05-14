
import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct SongsView: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.neiroArtworkVisible) private var artworkVisible
    @Query(sort: [SortDescriptor(\Track.title)]) private var tracks: [Track]
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var trackToDelete: Track? = nil
    @State private var showDeleteFileConfirm = false

    var body: some View {
        content
            .neiroPageBackground()
            .confirmationDialog(
                NeiroText.tr("确定要删除源文件吗？", "Delete source file?"),
                isPresented: $showDeleteFileConfirm,
                presenting: trackToDelete
            ) { track in
                Button(NeiroText.tr("删除", "Delete"), role: .destructive) {
                    LibraryActions.remove(track, deleteSourceFile: true, in: context)
                }
                Button(NeiroText.tr("取消", "Cancel"), role: .cancel) { }
            } message: { track in
                Text(NeiroText.tr(
                    "「\(track.title)」会从媒体库移除，磁盘上的源文件也将被删除。此操作不可撤销。",
                    "“\(track.title)” will be removed from the library, and the source file will be deleted permanently."
                ))
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: NeiroText.tr("全部歌曲", "Songs"), count: tracks.count)

            if tracks.isEmpty {
                EmptyState(
                    systemImage: "music.note",
                    title: NeiroText.tr("媒体库还是空的", "Library is empty"),
                    subtitle: NeiroText.tr("按 ⌘O 打开导入窗口，把音乐拖进去",
                                            "Press ⌘O to open import and drop music")
                )
            } else {
                Table(tracks, selection: $selectedIDs) {
                    TableColumn(NeiroText.tr("曲名", "Title")) { track in
                        HStack(spacing: 10) {
                            AlbumThumbnail(data: track.album?.artworkData, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).font(.body).lineLimit(1)
                                Text(track.artist?.name ?? NeiroText.tr("未知作曲家", "Unknown Artist"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { play(track) }
                    }
                    .width(min: 220, ideal: 360, max: 440)

                    TableColumn(NeiroText.tr("专辑", "Album")) { track in
                        Text(track.album?.name ?? "—")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .width(min: 140, ideal: 220, max: 280)

                    TableColumn(NeiroText.tr("时长", "Time")) { track in
                        Text(timeString(track.durationSeconds))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 60, ideal: 70, max: 80)

                    TableColumn(NeiroText.tr("格式", "Format")) { track in
                        formatBadge(track)
                    }
                    .width(min: 100, ideal: 120, max: 140)

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

                    TableColumn("") { _ in Color.clear }
                        .width(min: 0, ideal: 200, max: 999)
                }
                .scrollContentBackground(.hidden)
                .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
                    trackContextMenu(ids: ids)
                } primaryAction: { ids in
                    if let id = ids.first, let t = tracks.first(where: { $0.persistentModelID == id }) {
                        play(t)
                    }
                }
            }
        }
        .padding(20)
        .neiroArtworkMenu()
    }


    @ViewBuilder
    private func trackContextMenu(ids: Set<PersistentIdentifier>) -> some View {
        if ids.count == 1, let id = ids.first,
           let track = tracks.first(where: { $0.persistentModelID == id }) {
            Button {
                play(track)
            } label: {
                Label(NeiroText.tr("播放", "Play"), systemImage: "play.fill")
            }

            Button {
                LibraryActions.toggleFavorite(track, in: context)
            } label: {
                if track.isFavorite {
                    Label(NeiroText.tr("取消喜爱", "Unfavorite"), systemImage: "heart.slash")
                } else {
                    Label(NeiroText.tr("喜爱", "Favorite"), systemImage: "heart")
                }
            }

            Divider()

            Menu {
                ForEach(userPlaylists) { pl in
                    Button(pl.displayName) {
                        add(track: track, to: pl)
                    }
                }
                if userPlaylists.isEmpty {
                    Text(NeiroText.tr("没有自建播放列表", "No custom playlists"))
                }
            } label: {
                Label(NeiroText.tr("添加到播放列表", "Add to Playlist"), systemImage: "plus.rectangle.on.folder")
            }

            Divider()

            Button {
                associateLyric(with: track)
            } label: {
                Label(NeiroText.tr("关联歌词文件…", "Link Lyric File…"),
                      systemImage: "text.alignleft")
            }
            if track.lyricFilePath != nil {
                Button(role: .destructive) {
                    track.lyricFilePath = nil
                    track.lyricBookmarkData = nil
                    try? context.save()
                } label: {
                    Label(NeiroText.tr("解除歌词关联", "Unlink Lyric"),
                          systemImage: "text.alignleft.slash")
                }
            }

            Divider()

            if let album = track.album {
                Button {
                    router.go(.albums)
                } label: {
                    Label("\(NeiroText.tr("跳到专辑", "Go to Album"))：\(album.name)",
                          systemImage: "square.stack")
                }
            }
            if let artist = track.artist {
                Button {
                    router.go(.artists)
                } label: {
                    Label("\(NeiroText.tr("跳到作曲家", "Go to Artist"))：\(artist.name)",
                          systemImage: "person.2")
                }
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(track.filePath, forType: .string)
            } label: {
                Label(NeiroText.tr("复制文件路径", "Copy File Path"),
                      systemImage: "doc.on.doc")
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
            } label: {
                Label(NeiroText.tr("在访达中显示", "Show in Finder"), systemImage: "folder")
            }

            Divider()

            Button(role: .destructive) {
                LibraryActions.remove(track, deleteSourceFile: false, in: context)
            } label: {
                Label(NeiroText.tr("从媒体库移除（保留源文件）", "Remove from Library (keep file)"),
                      systemImage: "minus.circle")
            }
            Button(role: .destructive) {
                trackToDelete = track
                showDeleteFileConfirm = true
            } label: {
                Label(NeiroText.tr("从媒体库移除并删除源文件…", "Remove and Delete File…"),
                      systemImage: "trash")
            }
        } else if ids.count > 1 {
            Text(NeiroText.tr("已选 \(ids.count) 首", "\(ids.count) selected"))
            Button {
                let selected = tracks.filter { ids.contains($0.persistentModelID) }
                engine.playQueue(selected.map { $0.fileURL }, startAt: 0,
                                 shuffle: engine.isShuffleEnabled)
            } label: {
                Label(NeiroText.tr("作为队列播放", "Play as queue"), systemImage: "play.fill")
            }
        }
    }

    private var userPlaylists: [Playlist] {
        playlists.filter { $0.kind == .userCreated }
    }

    private func add(track: Track, to playlist: Playlist) {
        guard !playlist.tracks.contains(where: { $0.id == track.id }) else { return }
        playlist.tracks.append(track)
        try? context.save()
    }

    private func associateLyric(with track: Track) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var allowed: [UTType] = [.plainText, .text, .rtf]
        if let lrc = UTType(filenameExtension: "lrc") { allowed.append(lrc) }
        panel.allowedContentTypes = allowed
        panel.prompt = NeiroText.tr("关联", "Link")
        if panel.runModal() == .OK, let url = panel.url {
            track.lyricFilePath = url.path
            track.lyricBookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            try? context.save()
        }
    }

    private func removeFromLibrary(_ track: Track) {
        LibraryActions.remove(track, deleteSourceFile: false, in: context)
    }

    private func play(_ track: Track) {
        let idx = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
        engine.playQueue(tracks.map { $0.fileURL }, startAt: idx,
                         shuffle: engine.isShuffleEnabled)
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
