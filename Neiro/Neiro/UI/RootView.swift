//
//  RootView.swift
//  Neiro
//
//  Apple Music v11 风格三栏 panel 布局：
//    [ Sidebar ] [ Main (toolbar + content + InlinePlayerBar) ] [ Lyrics? ]
//  每个 panel 竖向铺满整个窗口高度，浮在窗口背景之上。
//

import SwiftUI
import SwiftData

public enum NavigationDestination: Hashable {
    case home
    case songs
    case albums
    case artists
    case playlists
    case playlist(UUID)
    case search
}

struct RootView: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(LibraryService.self) private var library
    @Environment(AppRouter.self) private var router
    @Environment(\.openWindow) private var openWindow

    private let sidebarWidth: CGFloat = 238
    private let lyricsWidth: CGFloat = 320
    private let outerPadding: CGFloat = 10
    private let verticalGap: CGFloat = 10

    var body: some View {
        @Bindable var router = router

        ZStack {
            AccentTintedBackground()

            VStack(spacing: verticalGap) {
                HStack(spacing: verticalGap) {
                    // 1. Sidebar panel（红绿灯在内部）
                    FloatingPanel {
                        Sidebar(selection: $router.selection)
                    }
                    .frame(width: sidebarWidth)

                    // 2. Main panel（toolbar + content）
                    FloatingPanel {
                        MainPanel()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 3. Lyrics panel（可隐藏）
                    if router.isLyricsPresented {
                        FloatingPanel {
                            LyricsPanel()
                        }
                        .frame(width: lyricsWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                BottomPlayerStrip()
            }
            .padding(outerPadding)
            .animation(.spring(response: 0.42, dampingFraction: 0.86),
                       value: router.isLyricsPresented)

            // 全屏 NowPlaying
            if router.isNowPlayingPresented {
                NowPlayingView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .neiroOpenImport)) { _ in
            openWindow(id: "import")
        }
    }
}

// MARK: - Main panel

private struct MainPanel: View {
    @Environment(AppRouter.self) private var router
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            MainToolbar()
            ContentSwitch(selection: router.selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Floating panel

struct FloatingPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }
}

// MARK: - Background

struct AccentTintedBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color.accentColor.opacity(0.05),
                    Color.accentColor.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Main toolbar（每页顶部 filter + 搜索 capsule）

private struct MainToolbar: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var router = router
        HStack(spacing: 10) {
            Spacer()

            // 导入按钮
            topGlassButton(systemName: "tray.and.arrow.down", help: NeiroText.tr("导入音乐 (⌘O)", "Import Music (⌘O)")) {
                openWindow(id: "import")
            }

            // 搜索胶囊
            SearchPill(text: $router.searchQuery) {
                if !$0.isEmpty { router.go(.search) }
            }
            .frame(width: 240)
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 6)
    }

    private func topGlassButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .background {
                    Circle().fill(.regularMaterial)
                    Circle().fill(Color.accentColor.opacity(0.08))
                }
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.7)
                )
                .shadow(color: .accentColor.opacity(0.14), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct BottomPlayerStrip: View {
    var body: some View {
        HStack {
            InlinePlayerBar()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
    }
}

private struct SearchPill: View {
    @Binding var text: String
    var onChange: (String) -> Void = { _ in }
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            TextField(NeiroText.tr("搜索曲目 · 作曲家 · 专辑", "Search songs · artists · albums"), text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focused)
                .onChange(of: text) { _, newValue in onChange(newValue) }
            if !text.isEmpty {
                Button {
                    text = ""
                    onChange("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Content switch

private struct ContentSwitch: View {
    let selection: NavigationDestination?

    var body: some View {
        Group {
            switch selection {
            case .home:               HomeView()
            case .songs:              SongsView()
            case .albums:             AlbumsView()
            case .artists:            ArtistsView()
            case .playlists:          PlaylistsView()
            case .playlist(let id):   PlaylistDetailView(playlistID: id)
            case .search:             SearchView()
            case .none:               HomeView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: selection)
    }
}
