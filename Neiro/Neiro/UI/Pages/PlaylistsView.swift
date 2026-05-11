//
//  PlaylistsView.swift
//  Neiro
//
//  Phase 1：列出默认 playlist。
//  立绘 PNG 仅在这一页右侧显示，固定比例 + 半透明，不挡操作。
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct PlaylistsView: View {
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @AppStorage(NeiroTheme.backgroundImagePathKey) private var bgImagePath: String = ""
    @AppStorage(NeiroTheme.backgroundOpacityKey) private var bgOpacity: Double = 0.45

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 主内容
            mainContent

            // 立绘：仅在 PlaylistsView 右下角，固定比例
            CharacterArtwork(imagePath: bgImagePath, opacity: bgOpacity)
                .allowsHitTesting(false)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
        }
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)],
                              alignment: .leading, spacing: 16) {
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
                    .padding(.top, 4)
                    // 留出右下角立绘空间
                    .padding(.trailing, bgImagePath.isEmpty ? 0 : 60)
                }
            }
        }
        .padding(20)
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

// MARK: - 立绘视图（保持原图比例）

private struct CharacterArtwork: View {
    let imagePath: String
    let opacity: Double

    var body: some View {
        if !imagePath.isEmpty, let img = NSImage(contentsOfFile: imagePath) {
            // 用原图比例展示，最大不超过容器一半高度 / 一定宽度
            GeometryReader { geo in
                let maxH = min(geo.size.height * 0.85, 720)
                let maxW = min(geo.size.width * 0.40, 480)
                let aspect = img.size.width / max(img.size.height, 1)
                // 根据宽高比决定以哪边为约束
                let (w, h): (CGFloat, CGFloat) = {
                    let byHeight = (maxH * aspect, maxH)
                    let byWidth  = (maxW, maxW / aspect)
                    return byHeight.0 <= maxW ? byHeight : byWidth
                }()

                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w, height: h)
                    .opacity(opacity)
                    .position(x: geo.size.width - w / 2,
                              y: geo.size.height - h / 2)
                    .animation(.easeInOut(duration: 0.35), value: imagePath)
            }
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
