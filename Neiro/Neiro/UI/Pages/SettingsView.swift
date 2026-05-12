//
//  SettingsView.swift
//  Neiro
//
//  Settings 场景，从 ⌘, 打开。
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettings()
                .tabItem { Label("外观", systemImage: "paintpalette") }
                .frame(width: 560, height: 460)

            LibrarySettings()
                .tabItem { Label("媒体库", systemImage: "music.note.list") }
                .frame(width: 560, height: 460)

            AboutSettings()
                .tabItem { Label("关于", systemImage: "info.circle") }
                .frame(width: 560, height: 460)
        }
    }
}

// MARK: - 外观

private struct AppearanceSettings: View {
    @AppStorage(NeiroTheme.accentKey) private var accentHex: String = ""
    @AppStorage(NeiroTheme.appearanceKey) private var appearanceRaw: String = NeiroAppearance.system.rawValue
    @AppStorage(NeiroTheme.backgroundImagePathKey) private var bgImagePath: String = ""
    @AppStorage(NeiroTheme.backgroundOpacityKey) private var bgOpacity: Double = 0.35
    @AppStorage(NeiroTheme.cornerRadiusKey) private var cornerRadius: Double = 14
    @AppStorage(NeiroTheme.animationSpeedKey) private var animationSpeed: Double = 1.0

    @State private var customColor: Color = .pink

    var body: some View {
        Form {
            Section("配色模式") {
                Picker("模式", selection: appearanceBinding) {
                    ForEach(NeiroAppearance.allCases) { a in
                        Text(a.label).tag(a)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("强调色") {
                LabeledContent("预设") {
                    HStack(spacing: 10) {
                        ForEach(NeiroTheme.presets, id: \.name) { preset in
                            Button {
                                accentHex = (preset.name == "系统蓝")
                                    ? ""
                                    : (NeiroTheme.hex(from: preset.color) ?? "")
                            } label: {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle().strokeBorder(
                                            isSelectedPreset(preset) ? Color.primary : Color.clear,
                                            lineWidth: 2)
                                    )
                                    .scaleEffect(isSelectedPreset(preset) ? 1.12 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7),
                                               value: accentHex)
                            }
                            .buttonStyle(.plain)
                            .help(preset.name)
                        }
                    }
                }

                LabeledContent("自定义") {
                    ColorPicker("", selection: $customColor, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: customColor) { _, newValue in
                            accentHex = NeiroTheme.hex(from: newValue) ?? ""
                        }
                }
            }

            Section {
                LabeledContent("当前") {
                    HStack {
                        if let img = previewImage {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .shadow(radius: 1)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.18))
                                .frame(width: 80, height: 50)
                                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            if bgImagePath.isEmpty {
                                Text("未设置").foregroundStyle(.secondary)
                            } else {
                                Text((bgImagePath as NSString).lastPathComponent).lineLimit(1)
                            }
                            Text(bgImagePath.isEmpty
                                 ? "在「播放列表」页右键也能设置"
                                 : bgImagePath)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }

                HStack {
                    Button("选择图片…") { chooseImage() }
                    Button("清除") { bgImagePath = "" }
                        .disabled(bgImagePath.isEmpty)
                }

                LabeledContent("透明度") {
                    HStack {
                        Slider(value: $bgOpacity, in: 0.10...1.0)
                        Text("\(Int(bgOpacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                .disabled(bgImagePath.isEmpty)
            } header: {
                Text("角色立绘（在所有列表页的右下角显示，保持原图比例）")
            }

            Section("细节") {
                LabeledContent("圆角强度") {
                    HStack {
                        Slider(value: $cornerRadius, in: 6...22, step: 1)
                        Text("\(Int(cornerRadius))pt")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                LabeledContent("动画速度") {
                    HStack {
                        Slider(value: $animationSpeed, in: 0.5...1.5, step: 0.1)
                        Text(String(format: "%.1f×", animationSpeed))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                Button("恢复默认") {
                    cornerRadius = 14
                    animationSpeed = 1.0
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { syncCustomColorFromHex() }
    }

    // MARK: helpers

    private var appearanceBinding: Binding<NeiroAppearance> {
        Binding(
            get: { NeiroAppearance(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    private func isSelectedPreset(_ preset: (name: String, color: Color)) -> Bool {
        if preset.name == "系统蓝" { return accentHex.isEmpty }
        return NeiroTheme.hex(from: preset.color) == accentHex
    }

    private func syncCustomColorFromHex() {
        if !accentHex.isEmpty, let c = NeiroTheme.color(fromHex: accentHex) {
            customColor = c
        }
    }

    private var previewImage: NSImage? {
        guard !bgImagePath.isEmpty else { return nil }
        return NSImage(contentsOfFile: bgImagePath)
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            bgImagePath = url.path
        }
    }
}

// MARK: - 媒体库

private struct LibrarySettings: View {
    @Environment(LibraryService.self) private var library
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var context
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neiro 不会扫描你的电脑")
                            .font(.callout.bold())
                        Text("库只包含你通过「导入音乐」窗口拖入或选中的内容。源文件留在原位置，Neiro 只记录路径和元数据。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.tint)
                }
            }

            Section("导入") {
                statusRow

                Button {
                    openWindow(id: "import")
                } label: {
                    Label("打开导入窗口…", systemImage: "tray.and.arrow.down")
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            Section("数据存放位置") {
                LabeledContent("App 数据库") {
                    Text(NeiroPaths.appSupport.path)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Button {
                    NSWorkspace.shared.open(NeiroPaths.appSupport)
                } label: {
                    Label("在访达打开", systemImage: "folder")
                }
            }

            Section("危险操作") {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("清空媒体库", systemImage: "trash")
                }
                .help("会移除所有曲目、专辑、作曲家的索引；源文件不动")
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog("确定清空整个媒体库吗？", isPresented: $showClearConfirm) {
            Button("清空", role: .destructive) {
                clearLibrary()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("会删除所有曲目、专辑、作曲家的索引（不动你的源文件）。默认播放列表会保留。")
        }
    }

    private func clearLibrary() {
        // 删 Track / Album / Artist；保留 Playlist 的默认条目（kindRaw 是 favorite* / anime）
        try? context.delete(model: Track.self)
        try? context.delete(model: Album.self)
        try? context.delete(model: Artist.self)
        try? context.save()
    }

    @ViewBuilder
    private var statusRow: some View {
        switch library.state {
        case .idle:
            LabeledContent("状态", value: "就绪")
        case .scanning(let found):
            LabeledContent("状态") {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("导入中… 已处理 \(found)")
                }
            }
        case .done(let imported, let updated, let skipped):
            LabeledContent("状态",
                           value: "已完成：新增 \(imported)，更新 \(updated)，跳过 \(skipped)")
        case .error(let msg):
            LabeledContent("错误") {
                Text(msg).foregroundStyle(.red)
            }
        }
    }
}

// MARK: - 关于

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Neiro").font(.largeTitle.bold())
            Text("Version 0.2 · Phase 2 in progress").foregroundStyle(.secondary)
            Divider().frame(width: 240)
            VStack(alignment: .leading, spacing: 8) {
                Label("MIT License", systemImage: "doc.text")
                Label("Open source on your computer", systemImage: "lock.open")
                Label("Built with SwiftUI & AVAudioEngine", systemImage: "hammer")
            }
            .foregroundStyle(.secondary)
            .font(.callout)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
