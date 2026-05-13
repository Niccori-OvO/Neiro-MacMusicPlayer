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
            GeneralSettings()
                .tabItem { Label(NeiroText.tr("通用", "General"), systemImage: "gearshape") }
                .frame(width: 560, height: 460)

            AppearanceSettings()
                .tabItem { Label(NeiroText.tr("外观与主题", "Appearance"), systemImage: "paintpalette") }
                .frame(width: 560, height: 460)

            LibrarySettings()
                .tabItem { Label(NeiroText.tr("媒体库与导入", "Library"), systemImage: "music.note.list") }
                .frame(width: 560, height: 460)

            AboutSettings()
                .tabItem { Label(NeiroText.tr("关于", "About"), systemImage: "info.circle") }
                .frame(width: 560, height: 460)
        }
    }
}

// MARK: - 通用

private struct GeneralSettings: View {
    @AppStorage(NeiroTheme.languageKey) private var languageRaw: String = NeiroLanguage.chinese.rawValue
    @AppStorage(NeiroTheme.homeSubtitleKey) private var homeSubtitle: String = NeiroTheme.defaultHomeSubtitle

    var body: some View {
        Form {
            Section(NeiroText.tr("语言", "Language")) {
                Picker(NeiroText.tr("应用语言", "App Language"), selection: languageBinding) {
                    ForEach(NeiroLanguage.allCases) { language in
                        Text(language.label).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                Text(NeiroText.tr("当前版本先覆盖主页问候语和设置主要文案；后续可扩展到全应用。", "This version first covers Home greetings and Settings copy, and can be expanded to the full app."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(NeiroText.tr("主页", "Home")) {
                TextField(NeiroText.tr("Home 副标题", "Home subtitle"), text: $homeSubtitle)
                Text(NeiroText.tr("显示在 Home 欢迎语下方", "Displayed below Home greeting"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(NeiroText.tr("恢复默认副标题", "Reset default subtitle")) {
                    homeSubtitle = NeiroTheme.defaultHomeSubtitle
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var languageBinding: Binding<NeiroLanguage> {
        Binding(
            get: { NeiroLanguage(rawValue: languageRaw) ?? .chinese },
            set: { languageRaw = $0.rawValue }
        )
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
            Section(NeiroText.tr("配色模式", "Color Mode")) {
                Picker(NeiroText.tr("模式", "Mode"), selection: appearanceBinding) {
                    ForEach(NeiroAppearance.allCases) { a in
                        Text(a.label).tag(a)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(NeiroText.tr("强调色", "Accent Color")) {
                LabeledContent(NeiroText.tr("预设", "Presets")) {
                    HStack(spacing: 10) {
                        ForEach(NeiroTheme.presets, id: \.name) { preset in
                            Button {
                                accentHex = (preset.name == NeiroText.tr("系统蓝", "System Blue"))
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

                LabeledContent(NeiroText.tr("自定义", "Custom")) {
                    ColorPicker("", selection: $customColor, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: customColor) { _, newValue in
                            accentHex = NeiroTheme.hex(from: newValue) ?? ""
                        }
                }
            }

            Section {
                LabeledContent(NeiroText.tr("当前", "Current")) {
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
                                Text(NeiroText.tr("未设置", "Not set")).foregroundStyle(.secondary)
                            } else {
                                Text((bgImagePath as NSString).lastPathComponent).lineLimit(1)
                            }
                            Text(bgImagePath.isEmpty
                                 ? NeiroText.tr("在「播放列表」页右键也能设置", "You can also set this via Playlists right-click")
                                 : bgImagePath)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }

                HStack {
                    Button(NeiroText.tr("选择图片…", "Choose Image…")) { chooseImage() }
                    Button(NeiroText.tr("清除", "Clear")) { bgImagePath = "" }
                        .disabled(bgImagePath.isEmpty)
                }

                LabeledContent(NeiroText.tr("透明度", "Opacity")) {
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
                Text(NeiroText.tr("角色立绘（在所有列表页的右下角显示，保持原图比例）", "Character artwork (shown bottom-right across list pages, preserving aspect ratio)"))
            }

            Section(NeiroText.tr("细节", "Details")) {
                LabeledContent(NeiroText.tr("圆角强度", "Corner Radius")) {
                    HStack {
                        Slider(value: $cornerRadius, in: 6...22, step: 1)
                        Text("\(Int(cornerRadius))pt")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                LabeledContent(NeiroText.tr("动画速度", "Animation Speed")) {
                    HStack {
                        Slider(value: $animationSpeed, in: 0.5...1.5, step: 0.1)
                        Text(String(format: "%.1f×", animationSpeed))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                Button(NeiroText.tr("恢复默认", "Reset Defaults")) {
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
        if preset.name == NeiroText.tr("系统蓝", "System Blue") { return accentHex.isEmpty }
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
        panel.prompt = NeiroText.tr("选择", "Choose")
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
    @AppStorage(NeiroTheme.copyOnImportKey) private var copyOnImport: Bool = true
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NeiroText.tr("Neiro 不会扫描你的电脑", "Neiro does not scan your computer"))
                            .font(.callout.bold())
                        Text(NeiroText.tr("库只包含你通过「导入音乐」窗口拖入或选中的内容。源文件留在原位置，Neiro 只记录路径和元数据。", "The library only includes items you drag into or choose in Import Music. Source files stay in place; Neiro stores paths and metadata only."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.tint)
                }
            }

            Section(NeiroText.tr("导入", "Import")) {
                Toggle(isOn: $copyOnImport) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NeiroText.tr("导入时复制到 Neiro 文件夹", "Copy to Neiro folder on import"))
                        Text(NeiroText.tr("开：源文件删除后仍能播放（推荐）  关：仅记录路径，源文件丢失会失效",
                                          "On: keeps working if source is deleted (recommended). Off: only references original location."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                statusRow

                Button {
                    openWindow(id: "import")
                } label: {
                    Label(NeiroText.tr("打开导入窗口…", "Open Import Window…"), systemImage: "tray.and.arrow.down")
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            Section(NeiroText.tr("数据存放位置", "Data Location")) {
                LabeledContent(NeiroText.tr("音乐库", "Music Library")) {
                    Text(NeiroPaths.musicLibrary.path)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                LabeledContent(NeiroText.tr("App 数据库", "App Database")) {
                    Text(NeiroPaths.appSupport.path)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                HStack {
                    Button {
                        NSWorkspace.shared.open(NeiroPaths.musicLibrary)
                    } label: {
                        Label(NeiroText.tr("打开音乐库", "Open Music Library"),
                              systemImage: "folder.fill")
                    }
                    Button {
                        NSWorkspace.shared.open(NeiroPaths.appSupport)
                    } label: {
                        Label(NeiroText.tr("打开数据目录", "Open Data Folder"),
                              systemImage: "folder")
                    }
                }
            }

            Section(NeiroText.tr("危险操作", "Danger Zone")) {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label(NeiroText.tr("清空媒体库", "Clear Library"), systemImage: "trash")
                }
                .help(NeiroText.tr("会移除所有曲目、专辑、作曲家的索引；源文件不动", "Removes all track/album/artist indexes; source files remain untouched"))
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog(NeiroText.tr("确定清空整个媒体库吗？", "Clear the entire library?"), isPresented: $showClearConfirm) {
            Button(NeiroText.tr("清空", "Clear"), role: .destructive) {
                clearLibrary()
            }
            Button(NeiroText.tr("取消", "Cancel"), role: .cancel) { }
        } message: {
            Text(NeiroText.tr("会删除所有曲目、专辑、作曲家的索引（不动你的源文件）。默认播放列表会保留。", "This deletes all track, album, and artist indexes (source files unchanged). Default playlists are kept."))
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
            LabeledContent(NeiroText.tr("状态", "Status"), value: NeiroText.tr("就绪", "Ready"))
        case .scanning(let found):
            LabeledContent(NeiroText.tr("状态", "Status")) {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(NeiroText.tr("导入中… 已处理 \(found)", "Importing… processed \(found)"))
                }
            }
        case .done(let imported, let updated, let skipped):
            LabeledContent(NeiroText.tr("状态", "Status"),
                           value: NeiroText.tr("已完成：新增 \(imported)，更新 \(updated)，跳过 \(skipped)", "Done: added \(imported), updated \(updated), skipped \(skipped)"))
        case .error(let msg):
            LabeledContent(NeiroText.tr("错误", "Error")) {
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
            Text("Version 0.2 beta v1.0").foregroundStyle(.secondary)
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
