//
//  HomeView.swift
//  Neiro
//
//  Phase 5 才会真正塞智能卡片（常听 / 推荐）。
//  Phase 1 先做欢迎页 + 库容总览 + 引导扫描。
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(LibraryService.self) private var library
    @Environment(\.openWindow) private var openWindow
    @Query private var tracks: [Track]
    @Query private var albums: [Album]
    @Query private var artists: [Artist]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                stats
                if tracks.isEmpty { emptyHint }
            }
            .padding(24)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("欢迎回来")
                .font(.largeTitle.bold())
            Text("Neiro · 你的本地音乐库")
                .foregroundStyle(.secondary)
        }
    }

    private var stats: some View {
        HStack(spacing: 16) {
            StatCard(icon: "music.note", title: "歌曲", value: "\(tracks.count)")
                .hoverLift()
            StatCard(icon: "square.stack", title: "专辑", value: "\(albums.count)")
                .hoverLift()
            StatCard(icon: "person.2", title: "作曲家", value: "\(artists.count)")
                .hoverLift()
        }
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("还没有歌曲", systemImage: "exclamationmark.circle")
                .font(.headline)
            Text("把音乐文件或文件夹拖进「导入音乐」窗口即可加入媒体库。源文件留在原位置，Neiro 不会扫描其它任何路径。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                openWindow(id: "import")
            } label: {
                Label("打开导入窗口", systemImage: "tray.and.arrow.down")
            }
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: [.command])
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neiroCard()
    }
}

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.bold().monospacedDigit())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neiroCard()
    }
}
