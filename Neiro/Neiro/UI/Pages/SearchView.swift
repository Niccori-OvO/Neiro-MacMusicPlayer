
import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AudioEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Track.title)])   private var allTracks: [Track]
    @Query(sort: [SortDescriptor(\Album.name)])    private var allAlbums: [Album]
    @Query(sort: \Artist.name)                      private var allArtists: [Artist]

    private var query: String {
        router.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var matchedTracks: [Track] {
        guard !query.isEmpty else { return [] }
        return allTracks.filter {
            $0.title.lowercased().contains(query)
            || ($0.artist?.name.lowercased().contains(query) ?? false)
            || ($0.album?.name.lowercased().contains(query) ?? false)
        }
    }

    private var matchedAlbums: [Album] {
        guard !query.isEmpty else { return [] }
        return allAlbums.filter {
            $0.name.lowercased().contains(query)
            || $0.artistName.lowercased().contains(query)
        }
    }

    private var matchedArtists: [Artist] {
        guard !query.isEmpty else { return [] }
        return allArtists.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: query.isEmpty ? NeiroText.tr("搜索", "Search") : "\(NeiroText.tr("搜索", "Search")) · \"\(router.searchQuery)\"",
                       count: query.isEmpty ? nil : matchedTracks.count + matchedAlbums.count + matchedArtists.count)

            if query.isEmpty {
                EmptyState(systemImage: "magnifyingglass",
                           title: NeiroText.tr("在顶部输入关键字开始搜索", "Enter a keyword in the top search bar"),
                           subtitle: NeiroText.tr("可以搜曲名、作曲家、专辑", "Search by title, artist, or album"))
            } else if matchedTracks.isEmpty && matchedAlbums.isEmpty && matchedArtists.isEmpty {
                EmptyState(systemImage: "questionmark.circle",
                           title: NeiroText.tr("没有匹配", "No matches"),
                           subtitle: NeiroText.tr("试试别的关键字", "Try a different keyword"))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !matchedArtists.isEmpty { artistSection }
                        if !matchedAlbums.isEmpty  { albumSection }
                        if !matchedTracks.isEmpty  { trackSection }
                    }
                    .padding(.top, 4)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .padding(24)
    }

    private var artistSection: some View {
        sectionWrap(NeiroText.tr("作曲家", "Artists"), count: matchedArtists.count) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(matchedArtists) { a in
                        HStack(spacing: 10) {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(a.name).font(.body.weight(.medium))
                                Text(NeiroText.tr("\(a.tracks.count) 首", "\(a.tracks.count) tracks")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var albumSection: some View {
        sectionWrap(NeiroText.tr("专辑", "Albums"), count: matchedAlbums.count) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(matchedAlbums) { album in
                        VStack(alignment: .leading, spacing: 6) {
                            AlbumThumbnail(data: album.artworkData, size: 120)
                            Text(album.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .frame(width: 120, alignment: .leading)
                            Text(album.artistName)
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 120, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var trackSection: some View {
        sectionWrap(NeiroText.tr("歌曲", "Songs"), count: matchedTracks.count) {
            VStack(spacing: 0) {
                ForEach(matchedTracks.prefix(20)) { t in
                    HStack {
                        AlbumThumbnail(data: t.album?.artworkData, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.title).font(.body)
                            Text(t.artist?.name ?? NeiroText.tr("未知作曲家", "Unknown Artist"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            LibraryActions.toggleFavorite(t, in: context)
                        } label: {
                            Image(systemName: t.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(t.isFavorite ? .pink : .secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        let urls = matchedTracks.map { $0.fileURL }
                        let idx = matchedTracks.firstIndex(where: { $0.id == t.id }) ?? 0
                        engine.playQueue(urls, startAt: idx, shuffle: engine.isShuffleEnabled)
                    }
                    Divider().opacity(0.4)
                }
                if matchedTracks.count > 20 {
                    Text(NeiroText.tr("还有 \(matchedTracks.count - 20) 首，搜索更具体一些…", "\(matchedTracks.count - 20) more results, refine your search…"))
                        .font(.caption).foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionWrap<Content: View>(
        _ title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title3.bold())
                Text("\(count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
            }
            content()
        }
    }
}
