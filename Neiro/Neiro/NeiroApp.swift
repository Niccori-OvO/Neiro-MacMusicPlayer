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
    @AppStorage(NeiroTheme.accentKey) private var accentHex: String = ""
    @AppStorage(NeiroTheme.appearanceKey) private var appearanceRaw: String = NeiroAppearance.system.rawValue

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
                .modelContainer(modelContainer)
                .tint(accentColor)
                .preferredColorScheme(NeiroAppearance(rawValue: appearanceRaw)?.colorScheme)
                .frame(minWidth: 880, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 Neiro") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("导入音乐…") {
                    NotificationCenter.default.post(name: .neiroOpenImport, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }

        // 独立的导入窗口
        Window("导入音乐", id: "import") {
            ImportView()
                .environment(engine)
                .environment(library)
                .modelContainer(modelContainer)
                .tint(accentColor)
                .preferredColorScheme(NeiroAppearance(rawValue: appearanceRaw)?.colorScheme)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
                .environment(engine)
                .environment(library)
                .modelContainer(modelContainer)
                .tint(accentColor)
                .preferredColorScheme(NeiroAppearance(rawValue: appearanceRaw)?.colorScheme)
        }
    }

    private var accentColor: Color {
        if accentHex.isEmpty { return .accentColor }
        return NeiroTheme.color(fromHex: accentHex) ?? .accentColor
    }
}
