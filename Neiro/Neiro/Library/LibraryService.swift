
import Foundation
import AVFoundation
import AudioToolbox
import CoreMedia
import AppKit
import SwiftData
import os

@MainActor
@Observable
public final class LibraryService {
    public enum ScanState: Equatable {
        case idle
        case scanning(found: Int)
        case done(imported: Int, updated: Int, skipped: Int)
        case error(String)
    }

    public private(set) var state: ScanState = .idle

    private let container: ModelContainer
    private static let log = Logger(subsystem: "app.neiro", category: "Library")

    public nonisolated static let supportedExtensions: Set<String> = [
        "flac", "alac", "m4a", "mp3", "wav", "wave",
        "aif", "aiff", "aifc", "caf", "aac", "mp4"
    ]

    public init(container: ModelContainer) {
        self.container = container
    }

    public func importItems(_ items: [URL]) async {
        // Keep all picked URLs scoped for the full import session.
        var startedAccess: [URL] = []
        for item in items where item.startAccessingSecurityScopedResource() {
            startedAccess.append(item)
        }
        defer {
            for url in startedAccess { url.stopAccessingSecurityScopedResource() }
        }

        state = .scanning(found: 0)
        let context = ModelContext(container)

        let urls = await Task.detached(priority: .userInitiated) { () -> [URL] in
            // Expand dropped folders into concrete audio-file URLs off the main actor.
            var collected: [URL] = []
            for item in items {
                if Self.isDirectory(item) {
                    collected.append(contentsOf: Self.enumerateAudioFiles(under: item))
                } else if Self.isSupportedAudio(item) {
                    collected.append(item)
                }
            }
            return collected
        }.value

        if urls.isEmpty {
            state = .done(imported: 0, updated: 0, skipped: 0)
            return
        }

        var imported = 0
        var updated = 0
        var skipped = 0

        for (i, url) in urls.enumerated() {
            if i % 8 == 0 { state = .scanning(found: i) }
            do {
                let result = try await importOne(url: url, into: context)
                switch result {
                case .imported: imported += 1
                case .updated: updated += 1
                case .skipped: skipped += 1
                }
            } catch {
                Self.log.error("import \(url.lastPathComponent) failed: \(error.localizedDescription)")
                skipped += 1
            }

            if i % 32 == 31 {
                try? context.save()
            }
        }

        try? context.save()
        state = .done(imported: imported, updated: updated, skipped: skipped)
    }


    nonisolated private static func enumerateAudioFiles(under root: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root,
                                             includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                             options: [.skipsHiddenFiles]) else {
            return []
        }
        var out: [URL] = []
        for case let url as URL in enumerator {
            if isSupportedAudio(url),
               (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                out.append(url)
            }
        }
        return out
    }

    nonisolated private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    nonisolated private static func isSupportedAudio(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }


    private enum ImportResult { case imported, updated, skipped }

    private func importOne(url: URL, into context: ModelContext) async throws -> ImportResult {
        let copyOn = UserDefaults.standard.object(forKey: NeiroTheme.copyOnImportKey) as? Bool ?? true
        let effectiveURL: URL = {
            if copyOn, let copied = copyToLibrary(url) {
                return copied
            }
            return url
        }()

        let path = effectiveURL.path
        let bookmark = makeBookmark(for: effectiveURL)

        let (lyricPath, lyricBookmark) = findAndCopyLyric(for: url, copy: copyOn)

        let descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.filePath == path })
        let existing = try context.fetch(descriptor).first

        let meta = try await MetadataExtractor.extract(url: url)

        if let track = existing {
            var didChange = false
            if track.title != meta.title { track.title = meta.title; didChange = true }
            if track.durationSeconds != meta.duration { track.durationSeconds = meta.duration; didChange = true }
            if track.sampleRate != meta.sampleRate { track.sampleRate = meta.sampleRate; didChange = true }
            if track.bitDepth != meta.bitDepth { track.bitDepth = meta.bitDepth; didChange = true }
            if track.channels != meta.channels { track.channels = meta.channels; didChange = true }
            if track.trackNumber != meta.trackNumber { track.trackNumber = meta.trackNumber; didChange = true }
            if track.discNumber != meta.discNumber { track.discNumber = meta.discNumber; didChange = true }
            if track.year != meta.year { track.year = meta.year; didChange = true }
            if track.genre != meta.genre { track.genre = meta.genre; didChange = true }
            if track.bookmarkData == nil, let bookmark {
                track.bookmarkData = bookmark
                didChange = true
            }
            if track.lyricFilePath == nil, let lyricPath {
                track.lyricFilePath = lyricPath
                track.lyricBookmarkData = lyricBookmark
                didChange = true
            }
            return didChange ? .updated : .skipped
        }

        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let track = Track(filePath: path,
                          title: meta.title,
                          durationSeconds: meta.duration,
                          fileSize: fileSize,
                          sampleRate: meta.sampleRate,
                          bitDepth: meta.bitDepth,
                          channels: meta.channels)
        track.trackNumber = meta.trackNumber
        track.discNumber = meta.discNumber
        track.year = meta.year
        track.genre = meta.genre
        track.bookmarkData = bookmark
        track.lyricFilePath = lyricPath
        track.lyricBookmarkData = lyricBookmark

        let artistName = meta.artist.isEmpty ? "未知作曲家" : meta.artist
        let artist = try findOrCreateArtist(name: artistName, in: context)
        track.artist = artist

        let albumName = meta.album.isEmpty ? "未知专辑" : meta.album
        let album = try findOrCreateAlbum(name: albumName, artistName: artistName, year: meta.year, in: context)
        track.album = album
        if album.artworkData == nil, let art = meta.artwork {
            album.artworkData = art
        }

        context.insert(track)
        attachAnimeProjects(for: track, in: context)
        return .imported
    }

    private func attachAnimeProjects(for track: Track, in context: ModelContext) {
        let projects = AnimeProjects.match(
            artist: track.artist?.name,
            album: track.album?.name,
            title: track.title
        )
        for project in projects {
            let pl = findOrCreateAnimePlaylist(project: project, in: context)
            if !pl.tracks.contains(where: { $0.id == track.id }) {
                pl.tracks.append(track)
            }
        }
    }

    private func findOrCreateAnimePlaylist(project: AnimeProject, in context: ModelContext) -> Playlist {
        let pid = project.id
        let descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.animeProjectID == pid }
        )
        if let existing = try? context.fetch(descriptor).first { return existing }
        let pl = Playlist(name: project.nameZH, kind: .anime, sortOrder: 1000)
        pl.animeProjectID = project.id
        context.insert(pl)
        return pl
    }

    public func reclassifyAnimeProjects() async {
        state = .scanning(found: 0)
        let context = ModelContext(container)

        let animeKind = Playlist.Kind.anime.rawValue
        let orphanDescriptor = FetchDescriptor<Playlist>(predicate: #Predicate {
            $0.kindRaw == animeKind && $0.animeProjectID == nil
        })
        if let orphans = try? context.fetch(orphanDescriptor) {
            for pl in orphans { context.delete(pl) }
        }

        let descriptor = FetchDescriptor<Track>()
        let allTracks = (try? context.fetch(descriptor)) ?? []
        for (i, t) in allTracks.enumerated() {
            if i % 16 == 0 { state = .scanning(found: i) }
            attachAnimeProjects(for: t, in: context)
        }

        let animeDescriptor = FetchDescriptor<Playlist>(predicate: #Predicate {
            $0.kindRaw == animeKind
        })
        if let all = try? context.fetch(animeDescriptor) {
            for pl in all where pl.tracks.isEmpty {
                context.delete(pl)
            }
        }

        try? context.save()
        state = .done(imported: 0, updated: allTracks.count, skipped: 0)
    }

    private func copyToLibrary(_ src: URL) -> URL? {
        let fm = FileManager.default
        let libDir = NeiroPaths.musicLibrary
        try? fm.createDirectory(at: libDir, withIntermediateDirectories: true)

        let scoped = src.startAccessingSecurityScopedResource()
        defer { if scoped { src.stopAccessingSecurityScopedResource() } }

        let baseName = src.deletingPathExtension().lastPathComponent
        let ext = src.pathExtension
        var target = libDir.appending(path: src.lastPathComponent)
        var index = 1
        while fm.fileExists(atPath: target.path) {
            if let srcSize = (try? src.resourceValues(forKeys: [.fileSizeKey]).fileSize),
               let dstSize = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize),
               srcSize == dstSize {
                return target // 视为已导入过，直接复用
            }
            target = libDir.appending(path: "\(baseName) (\(index)).\(ext)")
            index += 1
        }
        do {
            try fm.copyItem(at: src, to: target)
            return target
        } catch {
            Self.log.warning("copy to library failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func findAndCopyLyric(for src: URL, copy: Bool) -> (String?, Data?) {
        let fm = FileManager.default
        let candidate = src.deletingPathExtension().appendingPathExtension("lrc")

        let scoped = src.startAccessingSecurityScopedResource()
        defer { if scoped { src.stopAccessingSecurityScopedResource() } }

        guard fm.fileExists(atPath: candidate.path) else { return (nil, nil) }

        if copy {
            let lyricsDir = NeiroPaths.lyricsLibrary
            var target = lyricsDir.appending(path: candidate.lastPathComponent)
            var i = 1
            while fm.fileExists(atPath: target.path) {
                if let srcSize = (try? candidate.resourceValues(forKeys: [.fileSizeKey]).fileSize),
                   let dstSize = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize),
                   srcSize == dstSize {
                    return (target.path, makeBookmark(for: target))
                }
                target = lyricsDir.appending(path: "\(candidate.deletingPathExtension().lastPathComponent) (\(i)).lrc")
                i += 1
            }
            do {
                try fm.copyItem(at: candidate, to: target)
                return (target.path, makeBookmark(for: target))
            } catch {
                Self.log.warning("copy lyric failed: \(error.localizedDescription, privacy: .public)")
                return (candidate.path, makeBookmark(for: candidate))
            }
        } else {
            return (candidate.path, makeBookmark(for: candidate))
        }
    }

    nonisolated private func makeBookmark(for url: URL) -> Data? {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return nil
        }
    }

    private func findOrCreateArtist(name: String, in context: ModelContext) throws -> Artist {
        let descriptor = FetchDescriptor<Artist>(predicate: #Predicate { $0.name == name })
        if let existing = try context.fetch(descriptor).first { return existing }
        let a = Artist(name: name)
        context.insert(a)
        return a
    }

    private func findOrCreateAlbum(name: String,
                                   artistName: String,
                                   year: Int?,
                                   in context: ModelContext) throws -> Album {
        let key = Album.makeKey(artistName: artistName, name: name)
        let descriptor = FetchDescriptor<Album>(predicate: #Predicate { $0.key == key })
        if let existing = try context.fetch(descriptor).first { return existing }
        let a = Album(name: name, artistName: artistName, year: year)
        context.insert(a)
        return a
    }
}


enum MetadataExtractor {

    struct Metadata {
        var title: String
        var artist: String
        var album: String
        var trackNumber: Int?
        var discNumber: Int?
        var year: Int?
        var genre: String?
        var duration: Double
        var sampleRate: Double
        var bitDepth: Int
        var channels: Int
        var artwork: Data?
    }

    static func extract(url: URL) async throws -> Metadata {
        let asset = AVURLAsset(url: url)

        let duration: Double
        do {
            let cm = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cm)
        } catch {
            duration = 0
        }

        let allMeta = (try? await asset.load(.commonMetadata)) ?? []
        var title = url.deletingPathExtension().lastPathComponent
        var artist = ""
        var album = ""
        var year: Int?
        var artwork: Data?

        for item in allMeta {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                if let v = try? await item.load(.stringValue), !v.isEmpty { title = v }
            case .commonKeyArtist:
                if let v = try? await item.load(.stringValue) { artist = v }
            case .commonKeyAlbumName:
                if let v = try? await item.load(.stringValue) { album = v }
            case .commonKeyCreationDate:
                if let v = try? await item.load(.stringValue), let y = parseYear(v) { year = y }
            case .commonKeyArtwork:
                if let data = try? await item.load(.dataValue) {
                    artwork = downscaleArtwork(data)
                }
            default: break
            }
        }

        let defaultTitle = url.deletingPathExtension().lastPathComponent
        var trackNumber: Int?
        var discNumber: Int?
        var genre: String?
        let formats = (try? await asset.load(.availableMetadataFormats)) ?? []
        for fmt in formats {
            let items = (try? await asset.loadMetadata(for: fmt)) ?? []
            for item in items {
                guard let keyAny = item.key else { continue }
                let keyStr = "\(keyAny)".lowercased()

                if title == defaultTitle,
                   matchesAny(keyStr, ["title", "tit2", "©nam", "©NAM", "inam"]) {
                    if let v = try? await item.load(.stringValue), !v.isEmpty { title = v }
                }
                else if artist.isEmpty,
                        matchesAny(keyStr, ["artist", "tpe1", "©art", "©ART", "iart", "album_artist", "albumartist", "tpe2"]) {
                    if let v = try? await item.load(.stringValue), !v.isEmpty { artist = v }
                }
                else if album.isEmpty,
                        matchesAny(keyStr, ["album", "talb", "©alb", "©ALB", "iprd"]) {
                    if let v = try? await item.load(.stringValue), !v.isEmpty { album = v }
                }
                else if artwork == nil,
                        matchesAny(keyStr, ["picture", "apic", "covr", "metadata_block_picture"]) {
                    if let data = try? await item.load(.dataValue) {
                        artwork = downscaleArtwork(data)
                    }
                }
                else if matchesAny(keyStr, ["tracknumber", "trkn", "trck"]) {
                    if let v = try? await item.load(.stringValue) {
                        trackNumber = Int(v.split(separator: "/").first.map(String.init) ?? "") ?? trackNumber
                    } else if let v = try? await item.load(.numberValue) {
                        trackNumber = v.intValue
                    }
                }
                else if matchesAny(keyStr, ["discnumber", "disk", "tpos"]) {
                    if let v = try? await item.load(.stringValue) {
                        discNumber = Int(v.split(separator: "/").first.map(String.init) ?? "") ?? discNumber
                    } else if let v = try? await item.load(.numberValue) {
                        discNumber = v.intValue
                    }
                }
                else if matchesAny(keyStr, ["genre", "tcon", "©gen", "©GEN"]) {
                    if let v = try? await item.load(.stringValue) { genre = v }
                }
                else if matchesAny(keyStr, ["year", "date", "tyer", "tdrc", "©day"]) {
                    if year == nil, let v = try? await item.load(.stringValue), let y = parseYear(v) {
                        year = y
                    }
                }
            }
        }

        var sampleRate: Double = 0
        var bitDepth: Int = 0
        var channels: Int = 0
        do {
            let tracks = try await asset.load(.tracks)
            if let audioTrack = tracks.first(where: { $0.mediaType == .audio }) {
                let descs = try await audioTrack.load(.formatDescriptions)
                if let desc = descs.first {
                    if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
                        sampleRate = asbd.mSampleRate
                        channels = Int(asbd.mChannelsPerFrame)
                        if (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0 {
                            bitDepth = 32
                        } else {
                            bitDepth = Int(asbd.mBitsPerChannel)
                        }
                    }
                }
            }
        } catch {
        }

        return Metadata(title: title, artist: artist, album: album,
                        trackNumber: trackNumber, discNumber: discNumber,
                        year: year, genre: genre,
                        duration: duration,
                        sampleRate: sampleRate, bitDepth: bitDepth, channels: channels,
                        artwork: artwork)
    }

    private static func matchesAny(_ keyStr: String, _ needles: [String]) -> Bool {
        for n in needles {
            let lower = n.lowercased()
            if keyStr == lower || keyStr.contains(lower) { return true }
        }
        return false
    }

    private static func parseYear(_ s: String) -> Int? {
        let digits = s.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
        guard digits.count >= 4 else { return nil }
        let yearStr = String(String.UnicodeScalarView(digits.prefix(4)))
        return Int(yearStr)
    }

    private static func downscaleArtwork(_ data: Data, target: CGFloat = 256) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(target / size.width, target / size.height, 1)
        if scale >= 1 {
            return jpegify(image)
        }
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        resized.unlockFocus()
        return jpegify(resized)
    }

    private static func jpegify(_ image: NSImage, quality: CGFloat = 0.85) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}
