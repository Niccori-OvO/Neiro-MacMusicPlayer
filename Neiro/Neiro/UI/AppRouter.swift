//
//  AppRouter.swift
//  Neiro
//
//  全局导航 + 面板状态。
//

import Foundation
import SwiftUI

@MainActor
@Observable
public final class AppRouter {
    /// 当前 Sidebar 选中的页面
    public var selection: NavigationDestination? = .home

    /// Now Playing 全屏页是否展示
    public var isNowPlayingPresented: Bool = false

    /// 右侧歌词面板是否展示
    public var isLyricsPresented: Bool = false

    public init() {}

    public func go(_ dest: NavigationDestination) {
        selection = dest
    }

    public func presentNowPlaying() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isNowPlayingPresented = true
        }
    }

    public func dismissNowPlaying() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isNowPlayingPresented = false
        }
    }

    public func toggleLyrics() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isLyricsPresented.toggle()
        }
    }
}
