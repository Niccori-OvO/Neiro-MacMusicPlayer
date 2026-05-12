//
//  AppRouter.swift
//  Neiro
//

import Foundation
import SwiftUI

@MainActor
@Observable
public final class AppRouter {
    public var selection: NavigationDestination? = .home
    public var isNowPlayingPresented: Bool = false
    public var isLyricsPresented: Bool = false

    /// 全局搜索关键字
    public var searchQuery: String = ""

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
