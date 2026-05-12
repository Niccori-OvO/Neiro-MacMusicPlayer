//
//  RootView.swift
//  Neiro
//
//  顶层视图：左 Sidebar + 中主内容 + 底部贯穿播放栏。
//

import SwiftUI

public enum NavigationDestination: Hashable {
    case home
    case songs
    case albums
    case artists
    case playlists
    /// 指向某个具体 playlist 的页面（Phase 2 内容会接，骨架先打通）
    case playlist(UUID)
}

struct RootView: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(LibraryService.self) private var library
    @Environment(AppRouter.self) private var router
    @Environment(\.openWindow) private var openWindow
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        @Bindable var router = router
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                Sidebar(selection: $router.selection)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            } detail: {
                HStack(spacing: 0) {
                    MainContent(selection: router.selection)
                    if router.isLyricsPresented {
                        LyricsPanel()
                            .frame(width: 320)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                // 左侧：导入按钮，紧贴 sidebar toggle
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        openWindow(id: "import")
                    } label: {
                        Label("导入", systemImage: "tray.and.arrow.down")
                    }
                    .help("导入音乐 (⌘O)")
                }
                // 右侧：歌词 + 正在播放，让顶部左右平衡
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        router.toggleLyrics()
                    } label: {
                        Label("歌词", systemImage: "text.bubble")
                            .symbolVariant(router.isLyricsPresented ? .fill : .none)
                    }
                    .help("歌词面板")
                    .disabled(engine.currentURL == nil)

                    Button {
                        if engine.currentURL != nil {
                            router.presentNowPlaying()
                        }
                    } label: {
                        Label("正在播放", systemImage: "play.square")
                    }
                    .help("打开播放详情")
                    .disabled(engine.currentURL == nil)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PlayerBar()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        ZStack {
                            Rectangle().fill(.ultraThinMaterial)
                            Rectangle().fill(Color.accentColor.opacity(0.08))
                        }
                    }
                    .overlay(alignment: .top) {
                        Divider().opacity(0.5)
                    }
            }

            // 全屏 Now Playing overlay
            if router.isNowPlayingPresented {
                NowPlayingView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .neiroOpenImport)) { _ in
            openWindow(id: "import")
        }
    }
}

/// 浅色 + 强调色染色的页面背景。
/// windowBackgroundColor 跟随系统明暗自动选色，所以无论怎么切都不会过暗。
struct AccentTintedBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            // 主题色淡淡地染一层，深浅模式都柔和
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.10),
                    Color.accentColor.opacity(0.02),
                    Color.accentColor.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Main content switch

private struct MainContent: View {
    // 修复 Bug：加上 '?' 将其声明为可选类型，以接收调用方传来的可选值
    let selection: NavigationDestination?

    var body: some View {
        Group {
            switch selection {
            case .home:
                HomeView()
            case .songs:
                SongsView()
            case .albums:
                AlbumsView()
            case .artists:
                ArtistsView()
            case .playlists:
                PlaylistsView()
            case .playlist(let id):
                PlaylistDetailView(playlistID: id)
            case .none:
                HomeView()
            }
        }
        .id(selection)
        // 仅做内容淡入淡出...
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: selection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 把背景直接当成壁纸贴在最后面，并且让它无视安全区域铺满整个屏幕边缘
        .background {
            AccentTintedBackground()
                .ignoresSafeArea()
        }
    }
}
