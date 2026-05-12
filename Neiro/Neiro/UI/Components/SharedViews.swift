//
//  SharedViews.swift
//  Neiro
//
//  各浏览页共用的小组件。
//

import SwiftUI

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
            Text(title).font(.largeTitle.bold())
            if let count {
                Text("\(count)")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 12)
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

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
            if !imagePath.isEmpty {
                CharacterArtworkLayer(imagePath: imagePath, opacity: opacity)
                    .allowsHitTesting(false)
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
            }
        }
    }
}

struct CharacterArtworkLayer: View {
    let imagePath: String
    let opacity: Double

    var body: some View {
        if let img = NSImage(contentsOfFile: imagePath) {
            GeometryReader { geo in
                let maxH = min(geo.size.height * 0.85, 720)
                let maxW = min(geo.size.width * 0.40, 480)
                let aspect = img.size.width / max(img.size.height, 1)
                let (w, h): (CGFloat, CGFloat) = {
                    let byHeight = (maxH * aspect, maxH)
                    let byWidth  = (maxW, maxW / aspect)
                    return byHeight.0 <= maxW ? byHeight : byWidth
                }()
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w, height: h)
                    .opacity(opacity)
                    .position(x: geo.size.width - w / 2,
                              y: geo.size.height - h / 2)
                    .animation(.easeInOut(duration: 0.35), value: imagePath)
            }
        }
    }
}

// MARK: - Album thumbnail

struct AlbumThumbnail: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        Group {
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
