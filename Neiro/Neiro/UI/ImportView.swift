//
//  ImportView.swift
//  Neiro
//
//  导入音乐的独立窗口：大拖拽区 + 访达选取双轨。
//  从 File 菜单 ⌘O 或主壳的"导入"按钮打开。
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ImportView: View {
    @Environment(LibraryService.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var isTargeted = false
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            header

            dropZone
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .padding(28)
        .frame(width: 560, height: 460)
        .background {
            // 微妙的渐变玻璃感
            LinearGradient(
                colors: [.accentColor.opacity(0.12), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(NeiroText.tr("导入音乐", "Import Music")).font(.title2.bold())
                Text(NeiroText.tr("把文件夹或音频文件拖到下方区域", "Drop folders or audio files below"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch library.state {
        case .scanning(let n):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("\(n)").font(.caption.monospacedDigit())
            }
        case .done(let i, let u, let s):
            Label(NeiroText.tr("\(i + u) 首已入库", "\(i + u) imported"), systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .onAppear {
                    resultMessage = NeiroText.tr("新增 \(i)，更新 \(u)，跳过 \(s)", "Added \(i), updated \(u), skipped \(s)")
                }
        case .error(let m):
            Label(m, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        case .idle:
            EmptyView()
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isTargeted
                              ? Color.accentColor.opacity(0.10)
                              : Color.primary.opacity(0.03))
                )

            VStack(spacing: 12) {
                Image(systemName: isTargeted
                      ? "tray.and.arrow.down.fill"
                      : "tray.and.arrow.down")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: isTargeted)
                    .contentTransition(.symbolEffect(.replace))

                Text(isTargeted ? NeiroText.tr("松开导入", "Release to import") : NeiroText.tr("拖入这里", "Drop files here"))
                    .font(.title3.weight(.medium))

                Text(NeiroText.tr("支持的格式：FLAC · ALAC · WAV · AIFF · M4A · MP3 · CAF", "Supported: FLAC · ALAC · WAV · AIFF · M4A · MP3 · CAF"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let msg = resultMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                chooseWithPanel()
            } label: {
                Label(NeiroText.tr("从访达选取…", "Choose from Finder…"), systemImage: "folder")
            }
            .controlSize(.large)

            Spacer()

            if case .scanning = library.state {
                Text(NeiroText.tr("扫描中…", "Scanning…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(NeiroText.tr("完成", "Done")) { dismiss() }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - actions

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        Task {
            var urls: [URL] = []
            for provider in providers {
                if let url = await loadURL(from: provider) {
                    urls.append(url)
                }
            }
            await importURLs(urls)
        }
        return true
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                cont.resume(returning: url)
            }
        }
    }

    private func chooseWithPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = NeiroText.tr("导入", "Import")
        panel.allowedContentTypes = supportedTypes
        if panel.runModal() == .OK {
            let urls = panel.urls
            Task { await importURLs(urls) }
        }
    }

    private func importURLs(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        resultMessage = nil
        // 只导入用户实际拖进来 / 选中的内容：
        //   - 文件：导入这个文件
        //   - 目录：递归这个目录
        // 不会扫描传入路径之外的任何东西。
        await library.importItems(urls)
    }

    private var supportedTypes: [UTType] {
        var types: [UTType] = [.folder, .audio, .mp3, .wav, .aiff]
        for ext in ["m4a", "flac", "alac", "caf", "aac"] {
            if let t = UTType(filenameExtension: ext) { types.append(t) }
        }
        return types
    }
}
