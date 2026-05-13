//
//  NeiroApp.swift
//  Neiro
//
//  Created by Ethan Shen on 11/05/2026.
//

import SwiftUI
import SwiftData

extension Notification.Name {
    static let neiroOpenImport = Notification.Name("neiro.openImport")
}

@main
struct NeiroApp: App {
    @State private var engine = AudioEngine()
    @State private var library: LibraryService
    @State private var router = AppRouter()
    @AppStorage(NeiroTheme.accentKey) private var accentHex: String = ""
    @AppStorage(NeiroTheme.appearanceKey) private var appearanceRaw: String = NeiroAppearance.system.rawValue
    @AppStorage(NeiroTheme.languageKey) private var languageRaw: String = NeiroLanguage.chinese.rawValue

    let modelContainer: ModelContainer

    init() {
        NeiroPaths.bootstrap()

        let schema = Schema([Track.self, Album.self, Artist.self, Playlist.self])
        let config = ModelConfiguration("Library",
                                        schema: schema,
                                        url: NeiroPaths.databaseURL)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            self.modelContainer = container
            self._library = State(initialValue: LibraryService(container: container))

            DefaultPlaylists.ensureExist(in: container.mainContext)
        } catch {
            fatalError("SwiftData container init failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(engine)
                .environment(library)
                .environment(router)
                .modelContainer(modelContainer)
                .tint(accentColor)
                .preferredColorScheme(NeiroAppearance(rawValue: appearanceRaw)?.colorScheme)
                .frame(minWidth: 1245, minHeight: 600)
                .id(languageRaw) // 切换语言时强制 view 树重建以应用 NeiroText 翻译
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(NeiroText.tr("关于 Neiro", "About Neiro")) {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button(NeiroText.tr("导入音乐…", "Import Music…")) {
                    NotificationCenter.default.post(name: .neiroOpenImport, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }

        // 独立的导入窗口
        Window(NeiroText.tr("导入音乐", "Import Music"), id: "import") {
            ImportView()
                .environment(engine)
                .environment(library)
                .environment(router)
                .modelContainer(modelContainer)
                .tint(accentColor)
                .preferredColorScheme(NeiroAppearance(rawValue: appearanceRaw)?.colorScheme)
                .id(languageRaw)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
                .environment(engine)
                .environment(library)
                .environment(router)
                .modelContainer(modelContainer)
                .tint(accentColor)
                .preferredColorScheme(NeiroAppearance(rawValue: appearanceRaw)?.colorScheme)
                .id(languageRaw)
        }
    }

    private var accentColor: Color {
        if accentHex.isEmpty { return .accentColor }
        return NeiroTheme.color(fromHex: accentHex) ?? .accentColor
    }
}
