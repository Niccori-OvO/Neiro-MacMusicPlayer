
import Foundation
import SwiftData

@MainActor
public enum LibraryActions {

    public static func toggleFavorite(_ track: Track, in context: ModelContext) {
        track.isFavorite.toggle()
        syncFavoriteTracksPlaylist(for: track, in: context)
        try? context.save()
    }

    public static func setFavorite(_ isFavorite: Bool, on track: Track, in context: ModelContext) {
        guard track.isFavorite != isFavorite else { return }
        track.isFavorite = isFavorite
        syncFavoriteTracksPlaylist(for: track, in: context)
        try? context.save()
    }


    public static func toggleFavorite(_ album: Album, in context: ModelContext) {
        album.isFavorite.toggle()
        syncFavoriteAlbumsPlaylist(for: album, in: context)
        try? context.save()
    }

    public static func toggleFavorite(_ artist: Artist, in context: ModelContext) {
        artist.isFavorite.toggle()
        syncFavoriteArtistsPlaylist(for: artist, in: context)
        try? context.save()
    }


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



    public static func recordPlay(_ track: Track, in context: ModelContext) {
        track.playCount += 1
        track.lastPlayedAt = Date()
        try? context.save()
    }


    public static func remove(_ track: Track,
                              deleteSourceFile: Bool,
                              in context: ModelContext) {
        if deleteSourceFile {
            let url = track.fileURL
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            try? FileManager.default.removeItem(at: url)
            if let lyric = track.lyricURL {
                let s = lyric.startAccessingSecurityScopedResource()
                defer { if s { lyric.stopAccessingSecurityScopedResource() } }
                try? FileManager.default.removeItem(at: lyric)
            }
        }
        context.delete(track)
        try? context.save()
    }

    public static func remove(_ album: Album,
                              deleteSourceFiles: Bool,
                              in context: ModelContext) {
        for track in album.tracks {
            remove(track, deleteSourceFile: deleteSourceFiles, in: context)
        }
        context.delete(album)
        try? context.save()
    }

    public static func remove(_ artist: Artist,
                              deleteSourceFiles: Bool,
                              in context: ModelContext) {
        for track in artist.tracks {
            remove(track, deleteSourceFile: deleteSourceFiles, in: context)
        }
        context.delete(artist)
        try? context.save()
    }

    @discardableResult
    public static func purgeOrphans(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Track>()
        let tracks = (try? context.fetch(descriptor)) ?? []
        let fm = FileManager.default
        var removed = 0
        for t in tracks {
            let path = t.filePath
            if !fm.fileExists(atPath: path) {
                context.delete(t)
                removed += 1
            }
        }
        try? context.save()
        return removed
    }


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
