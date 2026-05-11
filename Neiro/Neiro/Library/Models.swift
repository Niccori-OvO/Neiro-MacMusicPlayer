//
//  Models.swift
//  Neiro
//
//  SwiftData 模型：Track / Album / Artist / Playlist
//  设计决策：
//    - 用文件 URL 的 `path` 作为 Track 的稳定唯一键（不存 Data bookmark 是因为
//      Phase 1 假设音乐都在 ~/Music/Neiro/ 里；Phase 2 处理可拖拽导入时再补 bookmark）
//    - 封面图存到 SwiftData 里的 Data（小图压缩到 256x256 JPEG，避免 DB 暴涨）
//    - 关系用 inverse 双向，让删除时级联干净
//

import Foundation
import SwiftData

// MARK: - Track

@Model
public final class Track {
    /// 文件路径（去掉 ~ 展开后）。作为查重和重新扫描的主键。
    @Attribute(.unique) public var filePath: String

    public var title: String
    public var trackNumber: Int?
    public var discNumber: Int?
    public var durationSeconds: Double
    public var year: Int?
    public var genre: String?
    /// 文件大小（字节）
    public var fileSize: Int64
    /// 源采样率，Hz
    public var sampleRate: Double
    /// 源位深
    public var bitDepth: Int
    /// 声道数
    public var channels: Int

    /// Phase 2 才会启用，预留
    public var isFavorite: Bool = false
    /// 添加进库时间
    public var addedAt: Date

    /// inverse 写在 Album/Artist/Playlist 的 to-many 侧
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

    /// URL（运行期构造，不持久化）
    public var fileURL: URL { URL(fileURLWithPath: filePath) }
}

// MARK: - Album

@Model
public final class Album {
    @Attribute(.unique) public var key: String   // "artistName::albumName"
    public var name: String
    public var artistName: String
    public var year: Int?
    /// 256x256 JPEG 缩略图
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

// MARK: - Artist（在 UI 里显示为"作曲家"）

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

// MARK: - Playlist

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
    /// 角色立绘 PNG，Phase 2 启用
    @Attribute(.externalStorage) public var backgroundImage: Data?

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
}

// MARK: - 默认 playlist 引导

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
