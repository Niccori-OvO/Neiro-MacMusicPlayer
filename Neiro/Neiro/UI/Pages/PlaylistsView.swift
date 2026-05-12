//
//  PlaylistsView.swift
//  Neiro
//
//  Phase 1：列出默认 playlist。立绘背景由共享 modifier 提供。
//

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
            PageHeader(title: "播放列表", count: playlists.count)

            if playlists.isEmpty {
                EmptyState(systemImage: "music.note.list",
                           title: "暂无播放列表",
                           subtitle: "默认列表会在首次启动时创建")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 18)],
                              alignment: .leading, spacing: 18) {
                        ForEach(playlists) { pl in
                            PlaylistCard(playlist: pl)
                                .hoverLift()
                                .contextMenu {
                                    Button("更换/导入立绘…") { chooseBackgroundImage() }
                                    if !bgImagePath.isEmpty {
                                        Button("清除立绘") { bgImagePath = "" }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.trailing, bgImagePath.isEmpty ? 8 : 60)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contextMenu {
            Button("更换/导入立绘…") { chooseBackgroundImage() }
            if !bgImagePath.isEmpty {
                Button("清除立绘") { bgImagePath = "" }
            }
        }
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            bgImagePath = url.path
        }
    }
}

// MARK: - 卡片

private struct PlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(height: 130)
            .shadow(radius: 3, y: 1)

            Text(playlist.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(playlist.tracks.count) 首")
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
