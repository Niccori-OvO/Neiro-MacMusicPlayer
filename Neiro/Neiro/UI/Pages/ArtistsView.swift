
import SwiftUI
import SwiftData

struct ArtistsView: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Query(sort: \Artist.name) private var artists: [Artist]
    @State private var selected: Artist?
    @State private var artistToDelete: Artist? = nil
    @State private var showDeleteFileConfirm = false

    var body: some View {
        content
            .sheet(item: $selected) { artist in
                ArtistDetailSheet(artist: artist)
            }
            .confirmationDialog(
                NeiroText.tr("确定要删除这位作曲家名下所有源文件吗？", "Delete all source files by this artist?"),
                isPresented: $showDeleteFileConfirm,
                presenting: artistToDelete
            ) { artist in
                Button(NeiroText.tr("全部删除", "Delete All"), role: .destructive) {
                    LibraryActions.remove(artist, deleteSourceFiles: true, in: context)
                }
                Button(NeiroText.tr("取消", "Cancel"), role: .cancel) { }
            } message: { artist in
                Text(NeiroText.tr(
                    "「\(artist.name)」共 \(artist.tracks.count) 首会一起被删除（包括磁盘文件）。此操作不可撤销。",
                    "“\(artist.name)” (\(artist.tracks.count) tracks) will be deleted from library AND disk. This cannot be undone."
                ))
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: NeiroText.tr("作曲家", "Artists"), count: artists.count)

            if artists.isEmpty {
                EmptyState(systemImage: "person.2", title: NeiroText.tr("暂无作曲家", "No artists yet"), subtitle: NeiroText.tr("导入音乐后会自动归类", "Artists will be grouped after import"))
            } else {
                List(selection: $selected) {
                    ForEach(artists) { artist in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist.name).font(.body)
                                Text(NeiroText.tr("\(artist.tracks.count) 首", "\(artist.tracks.count) tracks"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                LibraryActions.toggleFavorite(artist, in: context)
                            } label: {
                                Image(systemName: artist.isFavorite ? "heart.fill" : "heart")
                                    .foregroundStyle(artist.isFavorite ? .pink : .secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(NeiroText.tr("喜爱", "Favorite"))
                        }
                        .padding(.vertical, 4)
                        .tag(artist)
                        .contextMenu {
                            Button {
                                playArtist(artist, shuffle: false)
                            } label: {
                                Label(NeiroText.tr("播放", "Play"), systemImage: "play.fill")
                            }
                            Button {
                                playArtist(artist, shuffle: true)
                            } label: {
                                Label(NeiroText.tr("随机播放", "Shuffle"), systemImage: "shuffle")
                            }

                            Divider()

                            Button {
                                LibraryActions.toggleFavorite(artist, in: context)
                            } label: {
                                Label(artist.isFavorite
                                      ? NeiroText.tr("取消喜爱", "Unfavorite")
                                      : NeiroText.tr("喜爱作曲家", "Favorite Artist"),
                                      systemImage: artist.isFavorite ? "heart.slash" : "heart")
                            }

                            Divider()

                            Button(role: .destructive) {
                                LibraryActions.remove(artist, deleteSourceFiles: false, in: context)
                            } label: {
                                Label(NeiroText.tr("从媒体库移除（保留源文件）", "Remove from Library (keep files)"),
                                      systemImage: "minus.circle")
                            }
                            Button(role: .destructive) {
                                artistToDelete = artist
                                showDeleteFileConfirm = true
                            } label: {
                                Label(NeiroText.tr("从媒体库移除并删除源文件…", "Remove and Delete Files…"),
                                      systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .padding(20)
    }

    private func playArtist(_ artist: Artist, shuffle: Bool) {
        let sorted = artist.tracks.sorted { $0.title < $1.title }
        let urls = sorted.map { $0.fileURL }
        guard !urls.isEmpty else { return }
        engine.playQueue(urls, startAt: 0, shuffle: shuffle)
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
            Text(NeiroText.tr("\(artist.tracks.count) 首歌", "\(artist.tracks.count) songs")).foregroundStyle(.secondary)
            Divider()
            Table(artist.tracks.sorted { $0.title < $1.title }) {
                TableColumn(NeiroText.tr("曲名", "Title")) { t in
                    Text(t.title)
                        .onTapGesture(count: 2) {
                            let sorted = artist.tracks.sorted { $0.title < $1.title }
                            let urls = sorted.map { $0.fileURL }
                            let idx = sorted.firstIndex(where: { $0.id == t.id }) ?? 0
                            engine.playQueue(urls, startAt: idx, shuffle: engine.isShuffleEnabled)
                        }
                }
                TableColumn(NeiroText.tr("专辑", "Album")) { t in
                    Text(t.album?.name ?? "—").foregroundStyle(.secondary)
                }
                TableColumn(NeiroText.tr("时长", "Time")) { t in
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
