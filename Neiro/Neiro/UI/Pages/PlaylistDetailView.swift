//
//  PlaylistDetailView.swift
//  Neiro
//
//  单个 playlist 的详情页。Phase 2 才填实际曲目；现在先做骨架：
//  顶部封面 + 名字 + 曲数 + 占位内容区。
//

import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    let playlistID: UUID
    @Query private var allPlaylists: [Playlist]

    private var playlist: Playlist? {
        allPlaylists.first(where: { $0.id == playlistID })
    }

    var body: some View {
        content
            .neiroPageBackground()
    }

    @ViewBuilder
    private var content: some View {
        if let pl = playlist {
            VStack(alignment: .leading, spacing: 16) {
                header(pl)

                if pl.tracks.isEmpty {
                    EmptyState(
                        systemImage: "music.note.list",
                        title: "这个播放列表还是空的",
                        subtitle: pl.kind == .userCreated
                            ? "拖入歌曲（Phase 2 接入）"
                            : "喜爱歌曲后会自动出现在这里（Phase 2 接入）"
                    )
                } else {
                    EmptyState(
                        systemImage: "wrench.and.screwdriver",
                        title: "曲目列表即将上线",
                        subtitle: "已识别 \(pl.tracks.count) 首，Phase 2 会渲染"
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            EmptyState(systemImage: "questionmark.circle",
                       title: "找不到这个播放列表",
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
                Text("\(pl.tracks.count) 首歌")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

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
        case .favoriteTracks:  "默认 · 喜爱"
        case .favoriteAlbums:  "默认 · 专辑"
        case .favoriteArtists: "默认 · 作曲家"
        case .anime:           "默认 · 二次元企划"
        case .userCreated:     "自建"
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
