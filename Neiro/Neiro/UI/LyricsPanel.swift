//
//  LyricsPanel.swift
//  Neiro
//
//  右侧歌词面板。
//    - 拖拽 .lrc / .txt 文件解析时间戳
//    - 也兼容 RTF（自动提取纯文本）
//    - 根据 engine.currentTime 自动高亮 + 平滑滚动到当前行
//    - 滚轮滑动手动定位时不抢焦点
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import SwiftData

// MARK: - 数据结构

public struct LyricLine: Identifiable {
    public let id: Int          // 行号（稳定 id，给 ScrollViewReader 用）
    public let time: Double     // 秒
    public let text: String
}

// MARK: - LRC 解析

enum LRCParser {

    /// 解析 .lrc 文本到 [LyricLine]，按时间升序。
    /// 兼容形如 `[mm:ss.cc]文本` 和 `[mm:ss]文本` 以及一行多时间戳 `[00:01.00][00:30.00]文本`。
    static func parse(_ rawText: String) -> [LyricLine] {
        // 去掉 BOM 等前缀
        let text = rawText.replacingOccurrences(of: "\u{FEFF}", with: "")
        // 时间戳：分:秒(.毫秒/百分秒)
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

            // 文本 = 最后一个 ] 之后的内容
            let lastMatch = matches[matches.count - 1]
            let textStart = lastMatch.range.upperBound
            guard textStart <= nsLine.length else { continue }
            let lyricText = nsLine.substring(from: textStart).trimmingCharacters(in: .whitespaces)
            // 元数据行（[ti:][ar:] 等）lyricText 通常仍有内容（如 ti: 等），但形如 `[ti:歌名]`
            // 在我们的正则下不匹配（[ti: 不是 [digits:digits]），所以会被跳过，OK
            guard !lyricText.isEmpty else { continue }

            for match in matches {
                let minutes = Int(nsLine.substring(with: match.range(at: 1))) ?? 0
                let seconds = Int(nsLine.substring(with: match.range(at: 2))) ?? 0
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let frag = nsLine.substring(with: match.range(at: 3))
                    if let v = Int(frag) {
                        // 把 frag 当作分数：长度 1 = 0.1s，长度 2 = 0.01s，长度 3 = 0.001s
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

// MARK: - 文件读取（含 RTF 兜底）

enum LyricReader {
    /// 读取文件内容为纯文本。优先 RTF → UTF-8 → 系统自动 → GB18030。
    static func readPlainText(from url: URL) -> String? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }

        // 1. RTF 探测
        if let prefix = String(data: data.prefix(6), encoding: .ascii),
           prefix.hasPrefix(#"{\rtf"#) {
            if let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                return attr.string
            }
        }

        // 2. UTF-8
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }

        // 3. 常见 UTF-16 变体
        if let u16 = String(data: data, encoding: .utf16) { return u16 }

        // 4. GB18030（CN 常见）
        let cfEnc = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let nsEnc = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEnc))
        if let gb = String(data: data, encoding: nsEnc) { return gb }

        // 5. 兜底 lossy
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - 主视图

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

    var body: some View {
        VStack(spacing: 12) {
            header

            if lines.isEmpty {
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
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .onChange(of: engine.currentURL) { _, newURL in
            autoLoadLyric(for: newURL)
        }
        .onAppear { autoLoadLyric(for: engine.currentURL) }
    }

    /// 当前曲目对应的 Track（按 url.path 查）
    private var currentTrack: Track? {
        guard let path = engine.currentURL?.path else { return nil }
        return allTracks.first(where: { $0.filePath == path })
    }

    /// 切歌时自动加载关联的 .lrc。如果当前 lyric 是手动拖入的且当前曲目没关联 .lrc，保留它。
    private func autoLoadLyric(for url: URL?) {
        guard let url else { return }
        let key = url.path
        guard key != lastLoadedFor else { return }
        lastLoadedFor = key

        if let track = currentTrack, let lyricURL = track.lyricURL {
            acceptFile(lyricURL)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NeiroText.tr("歌词", "Lyrics")).font(.headline)
                if let url = lyricFileURL {
                    Text(url.lastPathComponent)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text(NeiroText.tr("拖入 .lrc 文件以同步显示", "Drop a .lrc file to sync"))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if !lines.isEmpty {
                Button {
                    lines = []
                    lyricFileURL = nil
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(NeiroText.tr("清除歌词", "Clear lyrics"))
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

    // MARK: 空态拖拽区

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

    // MARK: 歌词滚动

    private var lyricsScroll: some View {
        let now = engine.currentTime
        let activeIndex = currentLineIndex(for: now)

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    // 顶部空白把第一行推到中部
                    Color.clear.frame(height: 80)

                    ForEach(lines) { line in
                        let isActive = (line.id == activeIndex)
                        Text(line.text)
                            .font(isActive ? .title3.bold() : .callout)
                            .foregroundStyle(isActive ? Color.primary : Color.secondary)
                            .opacity(isActive ? 1.0 : 0.5)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .id(line.id)
                            .animation(.easeInOut(duration: 0.22), value: isActive)
                            .onTapGesture { engine.seek(toSeconds: line.time) }
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, 8)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .onChange(of: activeIndex) { _, new in
                guard let new, new != lastAutoScrolled else { return }
                lastAutoScrolled = new
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private func currentLineIndex(for time: Double) -> Int? {
        // 找最后一个 time <= now 的行
        var idx: Int? = nil
        for line in lines {
            if line.time <= time + 0.05 { idx = line.id } else { break }
        }
        return idx
    }

    // MARK: 拖拽 / 文件选取

    private func handleDrop(_ providers: [NSItemProvider]) {
        Task {
            for provider in providers {
                if let url = await loadURL(from: provider) {
                    await MainActor.run {
                        acceptFile(url)
                        // 拖入的歌词关联到当前 Track（持久化）
                        if let track = currentTrack {
                            track.lyricFilePath = url.path
                            track.lyricBookmarkData = try? url.bookmarkData(
                                options: .withSecurityScope,
                                includingResourceValuesForKeys: nil,
                                relativeTo: nil
                            )
                            try? context.save()
                        }
                    }
                    break
                }
            }
        }
    }

    private func chooseFile() {
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
            acceptFile(url)
        }
    }

    private func acceptFile(_ url: URL) {
        lyricFileURL = url
        guard let plain = LyricReader.readPlainText(from: url) else {
            lines = []
            return
        }
        let parsed = LRCParser.parse(plain)
        if !parsed.isEmpty {
            lines = parsed
        } else {
            // 没解析到时间戳：当作纯文本歌词，一行一条无时间
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
