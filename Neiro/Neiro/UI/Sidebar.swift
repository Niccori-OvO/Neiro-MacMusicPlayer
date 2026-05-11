//
//  Sidebar.swift
//  Neiro
//
//  左侧导航。Apple Music 风格：上面是固定入口，下面是自定义播放列表（Phase 2）。
//

import SwiftUI
import SwiftData

struct Sidebar: View {
    @Binding var selection: NavigationDestination?
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                NavigationLink(value: NavigationDestination.home) {
                    Label("Home", systemImage: "house")
                }
                NavigationLink(value: NavigationDestination.songs) {
                    Label("全部歌曲", systemImage: "music.note.list")
                }
                NavigationLink(value: NavigationDestination.albums) {
                    Label("专辑", systemImage: "square.stack")
                }
                NavigationLink(value: NavigationDestination.artists) {
                    Label("作曲家", systemImage: "person.2")
                }
            }

            Section("播放列表") {
                NavigationLink(value: NavigationDestination.playlists) {
                    Label("全部", systemImage: "music.note.list")
                        .badge(playlists.count)
                }
                // Phase 2 把 playlists 一条条列在这里
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Neiro")
    }
}
