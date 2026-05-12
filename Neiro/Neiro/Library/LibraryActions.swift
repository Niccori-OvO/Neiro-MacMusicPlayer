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

    /// 取「喜爱歌曲」playlist（按 kindRaw 找）。
    public static func favoriteTracksPlaylist(in context: ModelContext) -> Playlist? {
        let kind = Playlist.Kind.favoriteTracks.rawValue
        let descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.kindRaw == kind })
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
}
