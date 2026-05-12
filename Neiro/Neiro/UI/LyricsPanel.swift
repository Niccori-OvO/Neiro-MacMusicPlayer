//
//  LyricsPanel.swift
//  Neiro
//
//  右侧歌词面板骨架：
//    - 顶部：标题 + 关闭
//    - 中部：拖拽热区（.lrc）+ 已加载文件提示
//    - 下部：歌词显示区占位（Phase 3 接入解析与同步滚动）
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct LyricsPanel: View {
    @Environment(AppRouter.self) private var router
    @Environment(AudioEngine.self) private var engine
    @State private var isTargeted = false
    @State private var lyricFileURL: URL?
    @State private var rawText: String?

    var body: some View {
        VStack(spacing: 14) {
            header
            dropZone
            preview
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Color.accentColor.opacity(0.06))
            }
        }
        .overlay(alignment: .leading) {
            Divider().opacity(0.5)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("歌词").font(.headline)
                if let url = lyricFileURL {
                    Text(url.lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Phase 3 将接入解析与滚动同步")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                router.toggleLyrics()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isTargeted
                              ? Color.accentColor.opacity(0.12)
                              : Color.primary.opacity(0.02))
                )

            VStack(spacing: 8) {
                Image(systemName: isTargeted ? "doc.text.fill" : "doc.text")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: isTargeted)
                Text(isTargeted ? "松开导入" : "拖入 .lrc")
                    .font(.callout)
                Text("或者点击选取")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 110)
        .contentShape(Rectangle())
        .onTapGesture { chooseFile() }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            Task {
                for provider in providers {
                    if let url = await loadURL(from: provider),
                       url.pathExtension.lowercased() == "lrc" {
                        await MainActor.run { acceptLyricFile(url) }
                        break
                    }
                }
            }
            return true
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isTargeted)
    }

    @ViewBuilder
    private var preview: some View {
        if let raw = rawText {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(raw.split(separator: "\n").prefix(40)).indices, id: \.self) { i in
                        Text(String(raw.split(separator: "\n").prefix(40)[i]))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if raw.split(separator: "\n").count > 40 {
                        Text("…")
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "music.quarternote.3")
                    .font(.title)
                    .foregroundStyle(.tertiary)
                Text("解析与播放同步将在 Phase 3 上线")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        }
    }

    // MARK: - Helpers

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "导入"
        if let lrc = UTType(filenameExtension: "lrc") {
            panel.allowedContentTypes = [lrc, .plainText]
        } else {
            panel.allowedContentTypes = [.plainText]
        }
        if panel.runModal() == .OK, let url = panel.url {
            acceptLyricFile(url)
        }
    }

    private func acceptLyricFile(_ url: URL) {
        lyricFileURL = url
        rawText = (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .gbk_18030_2000))
            ?? (try? String(contentsOf: url))
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                cont.resume(returning: url)
            }
        }
    }
}

// 提供一个 GBK 编码常量（中文歌词常见编码）
private extension String.Encoding {
    static let gbk_18030_2000: String.Encoding = {
        let cfEnc = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let raw = CFStringConvertEncodingToNSStringEncoding(cfEnc)
        return String.Encoding(rawValue: raw)
    }()
}
