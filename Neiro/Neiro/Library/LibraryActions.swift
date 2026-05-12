//
//  LibraryActions.swift
//  Neiro
//
//  对 SwiftData 模型的小操作集合，让 UI 不直接耦合数据细节。
//

import Foundation
import SwiftData

@MainActor
public enum LibraryActions {

    /// 翻转 track 的喜爱状态，并自动同步「喜爱歌曲」播放列表。
    public static func toggleFavorite(_ track: Track, in context: ModelContext) {
        track.isFavorite.toggle()
        syncFavoriteTracksPlaylist(for: track, in: context)
        try? context.save()
    }

    /// 直接把 track 设为指定的喜爱状态。
    public static func setFavorite(_ isFavorite: Bool, on track: Track, in context: ModelContext) {
        guard track.isFavorite != isFavorite else { return }
        track.isFavorite = isFavorite
        syncFavoriteTracksPlaylist(for: track, in: context)
        try? context.save()
    }

    // MARK: - Album / Artist 喜爱

    /// 翻转 album 的喜爱状态，并把它名下所有 tracks 加入/移出「喜爱专辑」playlist。
    public static func toggleFavorite(_ album: Album, in context: ModelContext) {
        album.isFavorite.toggle()
        syncFavoriteAlbumsPlaylist(for: album, in: context)
        try? context.save()
    }

    /// 翻转 artist 的喜爱状态，并把它名下所有 tracks 加入/移出「喜爱作曲家」playlist。
    public static func toggleFavorite(_ artist: Artist, in context: ModelContext) {
        artist.isFavorite.toggle()
        syncFavoriteArtistsPlaylist(for: artist, in: context)
        try? context.save()
    }

    // MARK: - 默认 playlist 取值

    public static func favoriteTracksPlaylist(in context: ModelContext) -> Playlist? {
        defaultPlaylist(kind: .favoriteTracks, in: context)
    }

    public static func favoriteAlbumsPlaylist(in context: ModelContext) -> Playlist? {
        defaultPlaylist(kind: .favoriteAlbums, in: context)
    }

    public static func favoriteArtistsPlaylist(in context: ModelContext) -> Playlist? {
        defaultPlaylist(kind: .favoriteArtists, in: context)
    }

    private static func defaultPlaylist(kind: Playlist.Kind, in context: ModelContext) -> Playlist? {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.kindRaw == raw })
        return try? context.fetch(descriptor).first
    }

    // MARK: - Internal

    private static func syncFavoriteTracksPlaylist(for track: Track, in context: ModelContext) {
        guard let pl = favoriteTracksPlaylist(in: context) else { return }
        let id = track.id
        if track.isFavorite {
            if !pl.tracks.contains(where: { $0.id == id }) {
                pl.tracks.append(track)
            }
        } else {
            pl.tracks.removeAll(where: { $0.id == id })
        }
    }

    private static func syncFavoriteAlbumsPlaylist(for album: Album, in context: ModelContext) {
        guard let pl = favoriteAlbumsPlaylist(in: context) else { return }
        let albumTrackIDs = Set(album.tracks.map(\.id))
        if album.isFavorite {
            for t in album.tracks where !pl.tracks.contains(where: { $0.id == t.id }) {
                pl.tracks.append(t)
            }
        } else {
            pl.tracks.removeAll { albumTrackIDs.contains($0.id) }
        }
    }

    private static func syncFavoriteArtistsPlaylist(for artist: Artist, in context: ModelContext) {
        guard let pl = favoriteArtistsPlaylist(in: context) else { return }
        let artistTrackIDs = Set(artist.tracks.map(\.id))
        if artist.isFavorite {
            for t in artist.tracks where !pl.tracks.contains(where: { $0.id == t.id }) {
                pl.tracks.append(t)
            }
        } else {
            pl.tracks.removeAll { artistTrackIDs.contains($0.id) }
        }
    }
}
