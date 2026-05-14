
import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct PlaylistsView: View {
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @AppStorage(NeiroTheme.backgroundImagePathKey) private var bgImagePath: String = ""

    var body: some View {
        mainContent
            .neiroPageBackground()
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: NeiroText.tr("播放列表", "Playlists"), count: playlists.count)

            if playlists.isEmpty {
                EmptyState(systemImage: "music.note.list",
                           title: NeiroText.tr("暂无播放列表", "No playlists"),
                           subtitle: NeiroText.tr("默认列表会在首次启动时创建", "Default playlists are created on first launch"))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 18)],
                              alignment: .leading, spacing: 18) {
                        ForEach(playlists) { pl in
                            PlaylistCard(playlist: pl)
                                .hoverLift()
                                .contextMenu {
                                    Button(NeiroText.tr("更换/导入立绘…", "Change/Import Artwork…")) { chooseBackgroundImage() }
                                    if !bgImagePath.isEmpty {
                                        Button(NeiroText.tr("清除立绘", "Clear Artwork")) { bgImagePath = "" }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contextMenu {
            Button(NeiroText.tr("更换/导入立绘…", "Change/Import Artwork…")) { chooseBackgroundImage() }
            if !bgImagePath.isEmpty {
                Button(NeiroText.tr("清除立绘", "Clear Artwork")) { bgImagePath = "" }
            }
        }
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.prompt = NeiroText.tr("选择", "Choose")
        if panel.runModal() == .OK, let url = panel.url {
            bgImagePath = url.path
        }
    }
}


private struct PlaylistCard: View {
    let playlist: Playlist
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !playlist.tracks.isEmpty {
                    Button {
                        let urls = playlist.tracks.map { $0.fileURL }
                        engine.playQueue(urls, startAt: 0, shuffle: true)
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.32), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .help(NeiroText.tr("随机播放此 playlist", "Shuffle this playlist"))
                }
            }
            .frame(height: 130)
            .shadow(radius: 3, y: 1)

            Text(playlist.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(NeiroText.tr("\(playlist.tracks.count) 首", "\(playlist.tracks.count) tracks"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var icon: String {
        switch playlist.kind {
        case .favoriteTracks:  "heart.fill"
        case .favoriteAlbums:  "square.stack.fill"
        case .favoriteArtists: "star.fill"
        case .anime:           "sparkles"
        case .userCreated:     "music.note.list"
        }
    }

    private var gradient: [Color] {
        switch playlist.kind {
        case .favoriteTracks:  [Color(red: 1, green: 0.45, blue: 0.55), Color(red: 1, green: 0.71, blue: 0.83)]
        case .favoriteAlbums:  [Color(red: 0.45, green: 0.55, blue: 1), Color(red: 0.75, green: 0.65, blue: 0.93)]
        case .favoriteArtists: [Color(red: 1, green: 0.75, blue: 0.30), Color(red: 1, green: 0.55, blue: 0.42)]
        case .anime:           [Color(red: 0.78, green: 0.55, blue: 0.95), Color(red: 1.00, green: 0.71, blue: 0.83)]
        case .userCreated:     [.accentColor.opacity(0.7), .accentColor.opacity(0.35)]
        }
    }
}
