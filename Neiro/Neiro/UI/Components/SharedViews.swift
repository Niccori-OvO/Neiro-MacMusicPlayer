//
//  SharedViews.swift
//  Neiro
//
//  各浏览页共用的小组件。
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Page header

struct PageHeader: View {
    let title: String
    let count: Int?

    init(title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title.bold())
            if let count {
                Text("\(count)")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let systemImage: String
    let title: String
    let subtitle: String?

    init(systemImage: String, title: String, subtitle: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Page background with character artwork

public extension View {
    /// 给一个页面加立绘半透明背景层。立绘从 @AppStorage 读，靠右下角，保持原图比例。
    /// 所有列表页都应该用同一个，视觉一致。
    func neiroPageBackground() -> some View {
        modifier(NeiroPageBackground())
    }
}

private struct NeiroPageBackground: ViewModifier {
    @AppStorage(NeiroTheme.backgroundImagePathKey) private var imagePath: String = ""
    @AppStorage(NeiroTheme.backgroundOpacityKey) private var opacity: Double = 0.35
    @AppStorage(NeiroTheme.backgroundEnabledKey) private var enabled: Bool = true

    private var artworkVisible: Bool {
        !imagePath.isEmpty && enabled
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .environment(\.neiroArtworkVisible, artworkVisible)
            if artworkVisible {
                CharacterArtworkLayer(imagePath: imagePath, opacity: opacity)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: artworkVisible)
    }
}

// MARK: - 立绘开关 / 右键菜单 helper

private struct NeiroArtworkVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var neiroArtworkVisible: Bool {
        get { self[NeiroArtworkVisibleKey.self] }
        set { self[NeiroArtworkVisibleKey.self] = newValue }
    }
}

/// 列表区右键菜单的统一立绘开关组（任何 view 加 .neiroArtworkMenu() 即可）
public extension View {
    func neiroArtworkMenu() -> some View {
        modifier(NeiroArtworkMenu())
    }
}

private struct NeiroArtworkMenu: ViewModifier {
    @AppStorage(NeiroTheme.backgroundImagePathKey) private var imagePath: String = ""
    @AppStorage(NeiroTheme.backgroundEnabledKey) private var enabled: Bool = true

    func body(content: Content) -> some View {
        content.contextMenu {
            if !imagePath.isEmpty {
                Button {
                    enabled.toggle()
                } label: {
                    if enabled {
                        Label(NeiroText.tr("隐藏立绘", "Hide Character Art"),
                              systemImage: "eye.slash")
                    } else {
                        Label(NeiroText.tr("显示立绘", "Show Character Art"),
                              systemImage: "eye")
                    }
                }
                Button {
                    chooseImage()
                } label: {
                    Label(NeiroText.tr("更换立绘…", "Change Character Art…"),
                          systemImage: "photo")
                }
                Button(role: .destructive) {
                    imagePath = ""
                } label: {
                    Label(NeiroText.tr("清除立绘", "Clear Character Art"),
                          systemImage: "trash")
                }
            } else {
                Button {
                    chooseImage()
                } label: {
                    Label(NeiroText.tr("导入立绘…", "Import Character Art…"),
                          systemImage: "photo.badge.plus")
                }
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.prompt = NeiroText.tr("选择", "Choose")
        if panel.runModal() == .OK, let url = panel.url {
            imagePath = url.path
            enabled = true
        }
    }
}

/// 立绘图层：保持原图比例，底边对齐父容器底部，靠右。
/// 高度最多取父容器的 78%，宽度按比例计算。
struct CharacterArtworkLayer: View {
    let imagePath: String
    let opacity: Double

    var body: some View {
        if let img = NSImage(contentsOfFile: imagePath) {
            GeometryReader { geo in
                let maxH = geo.size.height * 0.78
                let maxW = geo.size.width * 0.30
                let aspect = img.size.width / max(img.size.height, 1)
                // 高度优先（保证一定纵向高度），按比例算宽，必要时按 maxW 收缩
                let h0 = maxH
                let w0 = h0 * aspect
                let (w, h): (CGFloat, CGFloat) = {
                    if w0 <= maxW { return (w0, h0) }
                    let w1 = maxW
                    let h1 = w1 / aspect
                    return (w1, h1)
                }()
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w, height: h)
                    .opacity(opacity)
                    // 底边贴 container 底，靠右
                    .position(x: geo.size.width - w / 2 - 6,
                              y: geo.size.height - h / 2)
                    .animation(.easeInOut(duration: 0.35), value: imagePath)
                    .animation(.easeInOut(duration: 0.25), value: opacity)
            }
        }
    }
}

// MARK: - Album thumbnail

struct AlbumThumbnail: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        ZStack {
            // 为带透明通道的封面提供底色，避免出现“切边/缺角”视觉问题。
            RoundedRectangle(cornerRadius: max(4, size * 0.08), style: .continuous)
                .fill(Color.black.opacity(0.18))

            if let data, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.accentColor.opacity(0.45), .accentColor.opacity(0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.08), style: .continuous))
        .shadow(radius: size > 80 ? 4 : 1, y: 1)
    }
}
