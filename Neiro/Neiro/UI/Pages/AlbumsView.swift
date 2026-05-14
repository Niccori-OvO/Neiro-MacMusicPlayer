
import SwiftUI
import SwiftData

struct AlbumsView: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Album.name)]) private var albums: [Album]
    @State private var selectedAlbum: Album?
    @State private var albumToDelete: Album? = nil
    @State private var showDeleteFileConfirm = false
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        content
            .sheet(item: $selectedAlbum) { album in
                AlbumDetailSheet(album: album)
            }
            .confirmationDialog(
                NeiroText.tr("确定要删除整张专辑的源文件吗？", "Delete all source files in this album?"),
                isPresented: $showDeleteFileConfirm,
                presenting: albumToDelete
            ) { album in
                Button(NeiroText.tr("全部删除", "Delete All"), role: .destructive) {
                    LibraryActions.remove(album, deleteSourceFiles: true, in: context)
                }
                Button(NeiroText.tr("取消", "Cancel"), role: .cancel) { }
            } message: { album in
                Text(NeiroText.tr(
                    "「\(album.name)」共 \(album.tracks.count) 首会一起被删除（包括磁盘文件）。此操作不可撤销。",
                    "“\(album.name)” (\(album.tracks.count) tracks) will be deleted from library AND disk. This cannot be undone."
                ))
            }
    }

    @ViewBuilder
    private func albumContextMenu(for album: Album) -> some View {
        Button {
            playAlbum(album, shuffle: false)
        } label: {
            Label(NeiroText.tr("播放", "Play"), systemImage: "play.fill")
        }
        Button {
            playAlbum(album, shuffle: true)
        } label: {
            Label(NeiroText.tr("随机播放", "Shuffle"), systemImage: "shuffle")
        }

        Divider()

        Button {
            LibraryActions.toggleFavorite(album, in: context)
        } label: {
            Label(album.isFavorite
                  ? NeiroText.tr("取消喜爱", "Unfavorite")
                  : NeiroText.tr("喜爱专辑", "Favorite Album"),
                  systemImage: album.isFavorite ? "heart.slash" : "heart")
        }

        Divider()

        Button(role: .destructive) {
            LibraryActions.remove(album, deleteSourceFiles: false, in: context)
        } label: {
            Label(NeiroText.tr("从媒体库移除（保留源文件）", "Remove from Library (keep files)"),
                  systemImage: "minus.circle")
        }
        Button(role: .destructive) {
            albumToDelete = album
            showDeleteFileConfirm = true
        } label: {
            Label(NeiroText.tr("从媒体库移除并删除源文件…", "Remove and Delete Files…"),
                  systemImage: "trash")
        }
    }

    private func playAlbum(_ album: Album, shuffle: Bool) {
        let sorted = album.tracks.sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }
        let urls = sorted.map { $0.fileURL }
        guard !urls.isEmpty else { return }
        engine.playQueue(urls, startAt: 0, shuffle: shuffle)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: NeiroText.tr("专辑", "Albums"), count: albums.count)
                .zIndex(1)

            if albums.isEmpty {
                EmptyState(systemImage: "square.stack",
                           title: NeiroText.tr("还没有专辑", "No albums yet"),
                           subtitle: NeiroText.tr("导入音乐后会自动按专辑归类", "Albums will be organized automatically after import"))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(albums) { album in
                            AlbumCard(album: album)
                                .hoverLift()
                                .onTapGesture { selectedAlbum = album }
                                .contextMenu { albumContextMenu(for: album) }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
                .clipped()
                .scrollContentBackground(.hidden)
                .zIndex(0)
            }
        }
        .padding(20)
    }
}

struct AlbumCard: View {
    let album: Album
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    AlbumThumbnail(data: album.artworkData, size: 152)
                }
                .frame(width: 160, height: 160)
                Button {
                    LibraryActions.toggleFavorite(album, in: context)
                } label: {
                    Image(systemName: album.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(album.isFavorite ? .pink : .white.opacity(0.95))
                        .padding(6)
                        .background(.black.opacity(0.32), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .help(NeiroText.tr("喜爱", "Favorite"))
            }
            Text(album.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(height: 40, alignment: .topLeading)
            Text(album.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: 16, alignment: .topLeading)
        }
        .frame(width: 160, alignment: .leading)
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
                    Text(NeiroText.tr("\(album.tracks.count) 首", "\(album.tracks.count) tracks"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            Table(album.tracks.sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }) {
                TableColumn("#") { t in
                    Text("\(t.trackNumber ?? 0)").foregroundStyle(.secondary)
                }.width(30)
                TableColumn(NeiroText.tr("曲名", "Title")) { t in
                    Text(t.title)
                        .onTapGesture(count: 2) {
                            let sorted = album.tracks.sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }
                            let urls = sorted.map { $0.fileURL }
                            let idx = sorted.firstIndex(where: { $0.id == t.id }) ?? 0
                            engine.playQueue(urls, startAt: idx, shuffle: engine.isShuffleEnabled)
                        }
                }
                TableColumn(NeiroText.tr("时长", "Time")) { t in
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
                Button(NeiroText.tr("关闭", "Close")) { dismiss() }
            }
        }
    }

    private func format(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
