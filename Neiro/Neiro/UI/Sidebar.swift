//
//  Sidebar.swift
//  Neiro
//
//  左侧导航。Apple Music 风格：上面是固定入口，下面列出每个 playlist。
//  选中项用强调色背景高亮（不是文字变色）。
//

import SwiftUI
import SwiftData

struct Sidebar: View {
    @Binding var selection: NavigationDestination?
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]

    @State private var showNewPlaylistSheet = false
    @State private var newPlaylistName = ""
    @State private var renamingID: UUID?
    @State private var renamingText = ""

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                row(.home,    label: "Home",       icon: "house")
                row(.songs,   label: "全部歌曲",   icon: "music.note.list")
                row(.albums,  label: "专辑",       icon: "square.stack")
                row(.artists, label: "作曲家",     icon: "person.2")
            }

            Section {
                ForEach(playlists) { pl in
                    NavigationLink(value: NavigationDestination.playlist(pl.id)) {
                        Label(pl.name, systemImage: icon(for: pl.kind))
                            .badge(pl.tracks.count)
                            .padding(.vertical, 2)
                    }
                    .contextMenu {
                        Button("打开") {
                            router.go(.playlist(pl.id))
                        }
                        if pl.kind == .userCreated {
                            Divider()
                            Button("重命名…") {
                                renamingID = pl.id
                                renamingText = pl.name
                            }
                            Button("删除", role: .destructive) {
                                delete(pl)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("播放列表")
                    Spacer()
                    Button {
                        newPlaylistName = ""
                        showNewPlaylistSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.plain)
                    .help("新建播放列表")
                }
                .padding(.top, 8)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Neiro")
        .safeAreaInset(edge: .top, spacing: 0) {
            // 顶部留位给 hiddenTitleBar 下的红绿黄交通灯按钮
            Color.clear.frame(height: 6)
        }
        .contextMenu {
            Button("新建播放列表…") {
                newPlaylistName = ""
                showNewPlaylistSheet = true
            }
        }
        // 新建 playlist
        .sheet(isPresented: $showNewPlaylistSheet) {
            NewPlaylistSheet(name: $newPlaylistName) { name in
                createPlaylist(named: name)
            }
        }
        // 重命名
        .sheet(item: renamingBinding) { id in
            RenamePlaylistSheet(name: $renamingText) { newName in
                renamePlaylist(id: id.id, to: newName)
            }
        }
    }

    @ViewBuilder
    private func row(_ dest: NavigationDestination, label: String, icon: String) -> some View {
        NavigationLink(value: dest) {
            Label(label, systemImage: icon)
        }
    }

    private func icon(for kind: Playlist.Kind) -> String {
        switch kind {
        case .favoriteTracks:  "heart"
        case .favoriteAlbums:  "square.stack"
        case .favoriteArtists: "star"
        case .anime:           "sparkles"
        case .userCreated:     "music.note.list"
        }
    }

    // MARK: - Actions

    private func createPlaylist(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let maxOrder = playlists.map(\.sortOrder).max() ?? 0
        let pl = Playlist(name: trimmed, kind: .userCreated, sortOrder: maxOrder + 1)
        context.insert(pl)
        try? context.save()
    }

    private func renamePlaylist(id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let pl = playlists.first(where: { $0.id == id }) else { return }
        pl.name = trimmed
        try? context.save()
    }

    private func delete(_ pl: Playlist) {
        // 仅允许删除用户创建的 playlist
        guard pl.kind == .userCreated else { return }
        context.delete(pl)
        try? context.save()
    }

    /// 把 renamingID 包装成 Identifiable 给 .sheet(item:) 用
    private var renamingBinding: Binding<IDWrapper?> {
        Binding(
            get: { renamingID.map(IDWrapper.init) },
            set: { renamingID = $0?.id }
        )
    }
}

// MARK: - Sheets

private struct IDWrapper: Identifiable { let id: UUID }

private struct NewPlaylistSheet: View {
    @Binding var name: String
    var onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建播放列表").font(.headline)
            TextField("名字", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("创建") { commit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { focused = true }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCreate(trimmed)
        dismiss()
    }
}

private struct RenamePlaylistSheet: View {
    @Binding var name: String
    var onRename: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名播放列表").font(.headline)
            TextField("名字", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { commit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { focused = true }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRename(trimmed)
        dismiss()
    }
}
