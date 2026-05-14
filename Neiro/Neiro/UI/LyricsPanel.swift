
import SwiftUI
import UniformTypeIdentifiers
import AppKit
import SwiftData


public struct LyricLine: Identifiable {
    // Stable row id keeps ScrollViewReader target mapping deterministic.
    public let id: Int
    public let time: Double
    public let text: String
}


enum LRCParser {

    static func parse(_ rawText: String) -> [LyricLine] {
        // Parse one or more [mm:ss.xx] tags per line and emit sorted timeline rows.
        let text = rawText.replacingOccurrences(of: "\u{FEFF}", with: "")
        let pattern = #"\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var result: [(time: Double, text: String)] = []

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            let matches = regex.matches(in: line, range: fullRange)
            guard !matches.isEmpty else { continue }

            let lastMatch = matches[matches.count - 1]
            let textStart = lastMatch.range.upperBound
            guard textStart <= nsLine.length else { continue }
            let lyricText = nsLine.substring(from: textStart).trimmingCharacters(in: .whitespaces)
            guard !lyricText.isEmpty else { continue }

            for match in matches {
                let minutes = Int(nsLine.substring(with: match.range(at: 1))) ?? 0
                let seconds = Int(nsLine.substring(with: match.range(at: 2))) ?? 0
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let frag = nsLine.substring(with: match.range(at: 3))
                    if let v = Int(frag) {
                        let denom = pow(10.0, Double(frag.count))
                        fraction = Double(v) / denom
                    }
                }
                let time = Double(minutes) * 60 + Double(seconds) + fraction
                result.append((time: time, text: lyricText))
            }
        }

        let sorted = result.sorted { $0.time < $1.time }
        return sorted.enumerated().map { (i, item) in
            LyricLine(id: i, time: item.time, text: item.text)
        }
    }
}


enum LyricReader {
    static func readPlainText(from url: URL) -> String? {
        // Try RTF and common text encodings before using lossy UTF-8 fallback.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }

        let rtfMagic: [UInt8] = [0x7B, 0x5C, 0x72, 0x74, 0x66]
        if data.count >= 5, Array(data.prefix(5)) == rtfMagic {
            if let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                return attr.string
            }
        }

        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }

        if let u16 = String(data: data, encoding: .utf16) { return u16 }

        let cfEnc = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let nsEnc = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEnc))
        if let gb = String(data: data, encoding: nsEnc) { return gb }

        return String(decoding: data, as: UTF8.self)
    }
}


struct LyricsPanel: View {
    @Environment(AppRouter.self) private var router
    @Environment(AudioEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Query private var allTracks: [Track]
    @State private var isTargeted = false
    @State private var lyricFileURL: URL?
    @State private var lines: [LyricLine] = []
    @State private var lastAutoScrolled: Int? = nil
    @State private var lastLoadedFor: String? = nil
    @State private var isUserDragged = false   // 用户手动滚动时暂停自动 follow
    @State private var lastUserInteract: Date = .distantPast
    
    private var hasActiveTrack: Bool { engine.currentURL != nil }
    private var isInstrumentalTrack: Bool {
        guard hasActiveTrack else { return false }
        let title = currentTrack?.title ?? engine.currentURL?.deletingPathExtension().lastPathComponent ?? ""
        let normalized = title.lowercased()
        return normalized.contains("纯音乐") || normalized.contains("instrumental")
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            if !hasActiveTrack {
                noPlaybackView
            } else if isInstrumentalTrack {
                instrumentalView
            } else if lines.isEmpty {
                emptyDropZone
            } else {
                lyricsScroll
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Color.accentColor.opacity(0.04))
            }
        }
        .overlay {
            if isTargeted && !lines.isEmpty {
                ZStack {
                    Color.accentColor.opacity(0.12)
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.accentColor)
                            .symbolEffect(.bounce, value: isTargeted)
                        Text(NeiroText.tr("松开以替换歌词", "Drop to replace lyrics"))
                            .font(.callout.weight(.medium))
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(8)
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard hasActiveTrack, !isInstrumentalTrack else { return false }
            handleDrop(providers)
            return true
        }
        .onChange(of: engine.currentURL) { _, newURL in
            autoLoadLyric(for: newURL)
        }
        .onAppear { autoLoadLyric(for: engine.currentURL) }
    }

    private var currentTrack: Track? {
        guard let url = engine.currentURL else { return nil }
        return allTracks.first(where: { $0.matches(url: url) })
    }

    private func autoLoadLyric(for url: URL?) {
        guard let url else { return }
        let key = url.path
        guard key != lastLoadedFor else { return }
        lastLoadedFor = key

        if isInstrumentalTrack {
            lines = []
            lyricFileURL = nil
            return
        }

        guard let track = currentTrack, let lyricURL = track.lyricURL else {
            lines = []
            lyricFileURL = nil
            return
        }

        let started = lyricURL.startAccessingSecurityScopedResource()
        defer { if started { lyricURL.stopAccessingSecurityScopedResource() } }
        acceptFile(lyricURL)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NeiroText.tr("歌词", "Lyrics")).font(.headline)
                if let url = lyricFileURL {
                    Text(url.lastPathComponent)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        .help(url.path)
                } else {
                    Text(!hasActiveTrack
                         ? NeiroText.tr("当前没有播放", "Nothing is playing")
                         : isInstrumentalTrack
                         ? NeiroText.tr("当前音乐是纯音乐，无歌词", "Current track is instrumental, no lyrics")
                         : NeiroText.tr("拖入 .lrc 文件以同步显示", "Drop a .lrc file to sync"))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if hasActiveTrack && !isInstrumentalTrack {
                Button {
                    chooseFile()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(NeiroText.tr("换一个歌词文件", "Change lyric file"))
            }
            if !lines.isEmpty && !isInstrumentalTrack {
                Button {
                    clearLyric()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(NeiroText.tr("清除并解除关联", "Clear & unlink"))
            }
            Button {
                router.toggleLyrics()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help(NeiroText.tr("关闭", "Close"))
        }
    }

    private func clearLyric() {
        lines = []
        lyricFileURL = nil
        if let track = currentTrack {
            track.lyricFilePath = nil
            track.lyricBookmarkData = nil
            try? context.save()
        }
    }

    
    private var noPlaybackView: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(NeiroText.tr("当前没有播放", "Nothing is playing"))
                .font(.callout.weight(.medium))
            Text(NeiroText.tr("请先播放一首歌曲，再导入或显示歌词", "Play a song first, then import or show lyrics"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var instrumentalView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(NeiroText.tr("当前音乐是纯音乐", "Current track is instrumental"))
                .font(.callout.weight(.medium))
            Text(NeiroText.tr("检测到当前歌曲是纯音乐，无歌词", "Current track is instrumental, no lyrics"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyDropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.02))
                )

            VStack(spacing: 8) {
                Image(systemName: isTargeted ? "doc.text.fill" : "doc.text")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: isTargeted)
                Text(isTargeted ? NeiroText.tr("松开导入", "Drop to import") : NeiroText.tr("拖入 .lrc", "Drop .lrc"))
                    .font(.callout)
                Text(NeiroText.tr("或者点击选取", "or click to pick"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { chooseFile() }
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isTargeted)
    }


    private var lyricsScroll: some View {
        let now = engine.currentTime
        let activeIndex = currentLineIndex(for: now)

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Color.clear.frame(height: 100)

                    ForEach(lines) { line in
                        let isActive = (line.id == activeIndex)
                        Text(line.text)
                            .font(isActive ? .system(size: 22, weight: .bold)
                                           : .system(size: 16, weight: .medium))
                            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                            .opacity(isActive ? 1.0 : 0.55)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(4)
                            .id(line.id)
                            .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isActive)
                            .contentShape(Rectangle())
                            .onTapGesture { engine.seek(toSeconds: line.time) }
                    }

                    Color.clear.frame(height: 160)
                }
                .padding(.horizontal, 14)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .onChange(of: activeIndex) { _, new in
                guard let new, new != lastAutoScrolled else { return }
                lastAutoScrolled = new
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private func currentLineIndex(for time: Double) -> Int? {
        var idx: Int? = nil
        for line in lines {
            if line.time <= time + 0.05 { idx = line.id } else { break }
        }
        return idx
    }


    private func handleDrop(_ providers: [NSItemProvider]) {
        guard hasActiveTrack, !isInstrumentalTrack else { return }
        Task {
            for provider in providers {
                if let url = await loadURL(from: provider) {
                    await MainActor.run { acceptAndBind(url) }
                    break
                }
            }
        }
    }

    private func chooseFile() {
        guard hasActiveTrack, !isInstrumentalTrack else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = NeiroText.tr("导入", "Import")
        var allowed: [UTType] = [.plainText, .text]
        if let lrc = UTType(filenameExtension: "lrc") { allowed.append(lrc) }
        allowed.append(.rtf)
        panel.allowedContentTypes = allowed
        if panel.runModal() == .OK, let url = panel.url {
            acceptAndBind(url)
        }
    }

    private func acceptAndBind(_ url: URL) {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }

        acceptFile(url)

        guard let track = currentTrack else { return }
        track.lyricFilePath = url.path
        track.lyricBookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try? context.save()
        lastLoadedFor = engine.currentURL?.path
    }

    private func acceptFile(_ url: URL) {
        guard hasActiveTrack, !isInstrumentalTrack else { return }
        lyricFileURL = url
        guard let plain = LyricReader.readPlainText(from: url) else {
            lines = []
            return
        }
        let parsed = LRCParser.parse(plain)
        if !parsed.isEmpty {
            lines = parsed
        } else {
            let plainLines = plain.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            lines = plainLines.enumerated().map { (i, t) in
                LyricLine(id: i, time: -1, text: t)
            }
        }
        lastAutoScrolled = nil
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                cont.resume(returning: url)
            }
        }
    }
}
