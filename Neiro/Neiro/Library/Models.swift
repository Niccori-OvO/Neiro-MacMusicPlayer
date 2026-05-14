
import Foundation
import SwiftData


@Model
public final class Track {
    @Attribute(.unique) public var filePath: String

    public var title: String
    public var trackNumber: Int?
    public var discNumber: Int?
    public var durationSeconds: Double
    public var year: Int?
    public var genre: String?
    public var fileSize: Int64
    public var sampleRate: Double
    public var bitDepth: Int
    public var channels: Int

    public var isFavorite: Bool = false
    public var addedAt: Date

    public var playCount: Int = 0
    public var lastPlayedAt: Date?

    @Attribute(.externalStorage) public var bookmarkData: Data?

    public var lyricFilePath: String?
    @Attribute(.externalStorage) public var lyricBookmarkData: Data?

    public var album: Album?
    public var artist: Artist?
    public var playlists: [Playlist] = []

    public init(filePath: String,
                title: String,
                durationSeconds: Double = 0,
                fileSize: Int64 = 0,
                sampleRate: Double = 0,
                bitDepth: Int = 0,
                channels: Int = 0) {
        self.filePath = filePath
        self.title = title
        self.durationSeconds = durationSeconds
        self.fileSize = fileSize
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.addedAt = Date()
    }

    public var fileURL: URL {
        if let bookmark = bookmarkData {
            var isStale = false
            if let restored = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return restored
            }
        }
        return URL(fileURLWithPath: filePath)
    }

    public func matches(url: URL) -> Bool {
        let urlPath = url.standardizedFileURL.resolvingSymlinksInPath().path
        let storedPath = URL(fileURLWithPath: filePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        if urlPath == storedPath { return true }
        if filePath == url.path { return true }
        if filePath.hasSuffix(url.lastPathComponent) { return true }
        return false
    }

    public var lyricURL: URL? {
        if let bookmark = lyricBookmarkData {
            var isStale = false
            if let restored = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return restored
            }
        }
        if let path = lyricFilePath {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}


@Model
public final class Album {
    @Attribute(.unique) public var key: String   // "artistName::albumName"
    public var name: String
    public var artistName: String
    public var year: Int?
    @Attribute(.externalStorage) public var artworkData: Data?
    public var isFavorite: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Track.album)
    public var tracks: [Track] = []

    public init(name: String, artistName: String, year: Int? = nil) {
        self.name = name
        self.artistName = artistName
        self.year = year
        self.key = Album.makeKey(artistName: artistName, name: name)
    }

    public static func makeKey(artistName: String, name: String) -> String {
        "\(artistName)::\(name)".lowercased()
    }
}


@Model
public final class Artist {
    @Attribute(.unique) public var name: String
    public var isFavorite: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Track.artist)
    public var tracks: [Track] = []

    public init(name: String) {
        self.name = name
    }
}


@Model
public final class Playlist {
    public enum Kind: String, Codable {
        case userCreated         // 用户自建
        case favoriteTracks      // 默认：喜爱歌曲
        case favoriteAlbums      // 默认：喜爱专辑
        case favoriteArtists     // 默认：喜爱作曲家
        case anime               // 默认：二次元企划自动加入
    }

    @Attribute(.unique) public var id: UUID
    public var name: String
    public var kindRaw: String
    public var createdAt: Date
    public var sortOrder: Int
    @Attribute(.externalStorage) public var backgroundImage: Data?
    public var animeProjectID: String?

    @Relationship(inverse: \Track.playlists)
    public var tracks: [Track] = []

    public var kind: Kind {
        get { Kind(rawValue: kindRaw) ?? .userCreated }
        set { kindRaw = newValue.rawValue }
    }

    public init(name: String, kind: Kind = .userCreated, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }

    public var displayName: String {
        switch kind {
        case .favoriteTracks:  return NeiroText.tr("喜爱歌曲", "Favorite Songs")
        case .favoriteAlbums:  return NeiroText.tr("喜爱专辑", "Favorite Albums")
        case .favoriteArtists: return NeiroText.tr("喜爱作曲家", "Favorite Artists")
        case .anime:
            if let pid = animeProjectID,
               let project = AnimeProjects.byID(pid) {
                return project.localizedName
            }
            return name
        case .userCreated:     return name
        }
    }

    public var animeCategory: AnimeCategory? {
        guard kind == .anime, let pid = animeProjectID else { return nil }
        return AnimeProjects.byID(pid)?.category
    }
}


public enum DefaultPlaylists {
    public static func ensureExist(in context: ModelContext) {
        let descriptors = [
            ("喜爱歌曲", Playlist.Kind.favoriteTracks, 0),
            ("喜爱专辑", Playlist.Kind.favoriteAlbums, 1),
            ("喜爱作曲家", Playlist.Kind.favoriteArtists, 2)
        ]
        for (name, kind, order) in descriptors {
            let rawKind = kind.rawValue
            let descriptor = FetchDescriptor<Playlist>(
                predicate: #Predicate { $0.kindRaw == rawKind }
            )
            if let existing = try? context.fetch(descriptor), !existing.isEmpty { continue }
            let pl = Playlist(name: name, kind: kind, sortOrder: order)
            context.insert(pl)
        }
        try? context.save()
    }
}
