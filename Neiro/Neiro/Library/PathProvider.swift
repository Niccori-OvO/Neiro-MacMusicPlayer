
import Foundation
import os

public enum NeiroPaths {

    private static let log = Logger(subsystem: "app.neiro", category: "Paths")

    public static var appSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support")
        return base.appending(path: "Neiro")
    }

    public static var databaseURL: URL {
        appSupport.appending(path: "library.store")
    }

    public static var preferredMusicLibrary: URL {
        let music = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Music")
        return music.appending(path: "Neiro")
    }

    public static var fallbackMusicLibrary: URL {
        appSupport.appending(path: "Music")
    }

    public static var musicLibrary: URL {
        if let cached = _resolvedMusicLibrary { return cached }
        let resolved = resolveMusicLibrary()
        _resolvedMusicLibrary = resolved
        return resolved
    }

    public static var lyricsLibrary: URL {
        let url = musicLibrary.appending(path: "Lyrics")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var _resolvedMusicLibrary: URL?

    public static var isUsingFallbackMusicLibrary: Bool {
        musicLibrary == fallbackMusicLibrary
    }

    private static func resolveMusicLibrary() -> URL {
        let fm = FileManager.default
        let preferred = preferredMusicLibrary
        if fm.fileExists(atPath: preferred.path) { return preferred }
        do {
            try fm.createDirectory(at: preferred, withIntermediateDirectories: true)
            log.info("created preferred music library at \(preferred.path, privacy: .public)")
            return preferred
        } catch {
            log.warning("preferred music library not writable (\(error.localizedDescription, privacy: .public)); using fallback")
            let fallback = fallbackMusicLibrary
            try? fm.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        }
    }

    public static func bootstrap() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: appSupport.path) {
            try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        _ = musicLibrary // 触发创建
    }
}
