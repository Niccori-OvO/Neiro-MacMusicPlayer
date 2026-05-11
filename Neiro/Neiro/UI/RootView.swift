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
}

struct RootView: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(LibraryService.self) private var library
    @Environment(\.openWindow) private var openWindow
    @State private var selection: NavigationDestination? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            MainContent(selection: selection)
        }
        .navigationSplitViewStyle(.balanced)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlayerBar()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.5)
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
    let selection: NavigationDestination?

    var body: some View {
        ZStack {
            AccentTintedBackground()

            Group {
                switch selection {
                case .home:      HomeView()
                case .songs:     SongsView()
                case .albums:    AlbumsView()
                case .artists:   ArtistsView()
                case .playlists: PlaylistsView()
                case .none:      HomeView()
                }
            }
            // 仅做内容淡入淡出，不影响外层 NavigationSplitView 的几何动画
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: selection)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
