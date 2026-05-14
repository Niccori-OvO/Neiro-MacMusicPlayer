
import SwiftUI
import UniformTypeIdentifiers


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


public extension View {
    func neiroPageBackground() -> some View {
        modifier(NeiroPageBackground())
    }
}

private struct NeiroPageBackground: ViewModifier {
    @AppStorage(NeiroTheme.backgroundImagePathKey) private var imagePath: String = ""
    @AppStorage(NeiroTheme.backgroundOpacityKey) private var opacity: Double = 0.35
    @AppStorage(NeiroTheme.backgroundEnabledKey) private var enabled: Bool = true
    @AppStorage(NeiroTheme.backgroundSizeRatioKey) private var sizeRatio: Double = 0.78

    private var artworkVisible: Bool {
        !imagePath.isEmpty && enabled
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .environment(\.neiroArtworkVisible, artworkVisible)
            if artworkVisible {
                CharacterArtworkLayer(
                    imagePath: imagePath,
                    opacity: opacity,
                    sizeRatio: CGFloat(sizeRatio)
                )
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: artworkVisible)
    }
}


private struct NeiroArtworkVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var neiroArtworkVisible: Bool {
        get { self[NeiroArtworkVisibleKey.self] }
        set { self[NeiroArtworkVisibleKey.self] = newValue }
    }
}

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

struct CharacterArtworkLayer: View {
    let imagePath: String
    let opacity: Double
    let sizeRatio: CGFloat

    init(imagePath: String, opacity: Double, sizeRatio: CGFloat = 0.78) {
        self.imagePath = imagePath
        self.opacity = opacity
        self.sizeRatio = sizeRatio
    }

    var body: some View {
        if let img = NSImage(contentsOfFile: imagePath) {
            GeometryReader { geo in
                let maxH = geo.size.height * sizeRatio
                let maxW = geo.size.width * (0.25 + sizeRatio * 0.15)
                let aspect = img.size.width / max(img.size.height, 1)
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
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear,                  location: 0.00),
                                .init(color: .black.opacity(0.35),    location: 0.10),
                                .init(color: .black.opacity(0.85),    location: 0.28),
                                .init(color: .black,                  location: 0.45),
                                .init(color: .black,                  location: 1.00),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                    .opacity(opacity)
                    .position(x: geo.size.width - w / 2 - 6,
                              y: geo.size.height - h / 2)
                    .animation(.easeInOut(duration: 0.35), value: imagePath)
                    .animation(.easeInOut(duration: 0.25), value: opacity)
                    .animation(.easeInOut(duration: 0.25), value: sizeRatio)
            }
        }
    }
}


struct AlbumThumbnail: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        ZStack {
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
