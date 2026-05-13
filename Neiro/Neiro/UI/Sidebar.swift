//
//  Sidebar.swift
//  Neiro
//
//  左侧固定导航。
//

import SwiftUI
import SwiftData
import AppKit

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
        VStack(spacing: 0) {
            WindowControlsRow()
                .padding(.horizontal, 14)
                .padding(.top, 9)
                .padding(.bottom, 4)

            List(selection: $selection) {
            Section {
                row(.home,    label: NeiroText.tr("首页", "Home"), icon: "house")
                row(.songs,   label: NeiroText.tr("全部歌曲", "Songs"), icon: "music.note.list")
                row(.albums,  label: NeiroText.tr("专辑", "Albums"), icon: "square.stack")
                row(.artists, label: NeiroText.tr("作曲家", "Artists"), icon: "person.2")
            } header: {
                sectionHeader(title: NeiroText.tr("资料库", "Library"), action: nil)
            }

            Section {
                ForEach(playlists) { pl in
                    Label {
                        HStack {
                            Text(pl.displayName).lineLimit(1)
                            Spacer()
                            if pl.tracks.count > 0 {
                                Text("\(pl.tracks.count)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: icon(for: pl.kind))
                            .frame(width: 18, alignment: .center)
                    }
                    .padding(.vertical, 3)
                    .tag(NavigationDestination.playlist(pl.id))
                    .contextMenu {
                        Button(NeiroText.tr("打开", "Open")) { router.go(.playlist(pl.id)) }
                        if pl.kind == .userCreated {
                            Divider()
                            Button(NeiroText.tr("重命名…", "Rename…")) {
                                renamingID = pl.id
                                renamingText = pl.name
                            }
                            Button(NeiroText.tr("删除", "Delete"), role: .destructive) { delete(pl) }
                        }
                    }
                }
            } header: {
                sectionHeader(title: NeiroText.tr("播放列表", "Playlists")) {
                    newPlaylistName = ""
                    showNewPlaylistSheet = true
                }
            }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .contextMenu {
            Button(NeiroText.tr("新建播放列表…", "New Playlist…")) {
                newPlaylistName = ""
                showNewPlaylistSheet = true
            }
        }
        .sheet(isPresented: $showNewPlaylistSheet) {
            NewPlaylistSheet(name: $newPlaylistName) { createPlaylist(named: $0) }
        }
        .sheet(item: renamingBinding) { id in
            RenamePlaylistSheet(name: $renamingText) { renamePlaylist(id: id.id, to: $0) }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func sectionHeader(title: String, action: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Spacer()
            if let action {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 14)
                }
                .buttonStyle(.plain)
                .offset(y: 1)
                .help(NeiroText.tr("新建播放列表", "New Playlist"))
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func row(_ dest: NavigationDestination, label: String, icon: String) -> some View {
        Label {
            Text(label)
        } icon: {
            Image(systemName: icon)
                .frame(width: 18, alignment: .center)
        }
        .padding(.vertical, 3)
        .tag(dest)
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
        guard pl.kind == .userCreated else { return }
        context.delete(pl)
        try? context.save()
    }

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
            Text(NeiroText.tr("新建播放列表", "New Playlist")).font(.headline)
            TextField(NeiroText.tr("名字", "Name"), text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button(NeiroText.tr("取消", "Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(NeiroText.tr("创建", "Create")) { commit() }
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

private struct WindowControlsRow: View {
    var body: some View {
        HStack {
            SystemWindowControlsHost()
                .frame(width: 62, height: 14)
            Spacer(minLength: 0)
        }
        .frame(height: 18)
    }
}

private struct SystemWindowControlsHost: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.wantsLayer = false
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            attachSystemButtons(to: nsView, in: window)
        }
    }

    private func attachSystemButtons(to host: NSView, in window: NSWindow) {
        let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let spacing: CGFloat = 8

        for (index, type) in types.enumerated() {
            guard let button = window.standardWindowButton(type) else { continue }
            if button.superview !== host {
                button.removeFromSuperview()
                host.addSubview(button)
            }
            button.translatesAutoresizingMaskIntoConstraints = true
            let y = max(0, (host.bounds.height - button.frame.height) * 0.5)
            button.frame.origin = CGPoint(x: CGFloat(index) * (button.frame.width + spacing), y: y)
            button.isHidden = false
        }
    }
}

private struct RenamePlaylistSheet: View {
    @Binding var name: String
    var onRename: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NeiroText.tr("重命名播放列表", "Rename Playlist")).font(.headline)
            TextField(NeiroText.tr("名字", "Name"), text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button(NeiroText.tr("取消", "Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(NeiroText.tr("保存", "Save")) { commit() }
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
