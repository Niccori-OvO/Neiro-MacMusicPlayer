//
//  Theme.swift
//  Neiro
//
//  Liquid Glass / 调色板 helper。
//
//  Phase 1 策略：全部用 .regularMaterial / .ultraThinMaterial 模拟玻璃感，
//  在 macOS 14+ 上都能跑且视觉一致。
//  待 macOS 26 Liquid Glass API 完全稳定后，在 `glassBackground` 处接入即可，
//  不影响调用方。
//

import SwiftUI

// MARK: - Glass effect modifier

public extension View {

    /// 通用玻璃背景。
    func neiroGlass(cornerRadius: CGFloat = 16,
                    material: Material = .regularMaterial,
                    tint: Color? = nil) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, material: material, tint: tint))
    }

    /// 浮岛卡片：玻璃背景 + accent 染色 + 描边 + 染色阴影。
    /// 主题色会让卡片底色 / 边框 / 阴影都跟着变。
    func neiroCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .neiroGlass(cornerRadius: cornerRadius, tint: .accentColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .accentColor.opacity(0.18), radius: 14, y: 6)
    }
}

private struct GlassBackground: ViewModifier {
    let cornerRadius: CGFloat
    let material: Material
    let tint: Color?

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.10))
                }
            }
        }
    }
}

// MARK: - Appearance

public enum NeiroLanguage: String, CaseIterable, Identifiable {
    case chinese
    case english

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        }
    }
}

public enum NeiroAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .system: NeiroText.tr("跟随系统", "System")
        case .light:  NeiroText.tr("浅色", "Light")
        case .dark:   NeiroText.tr("深色", "Dark")
        }
    }
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

// MARK: - Accent color

public enum NeiroTheme {
    /// 用户自定义强调色 key（UserDefaults）
    public static let accentKey = "NeiroAccentColor"

    /// 明暗模式 key
    public static let appearanceKey = "NeiroAppearance"

    /// 应用级背景立绘 PNG 绝对路径 key
    public static let backgroundImagePathKey = "NeiroBackgroundImagePath"

    /// 背景立绘透明度
    public static let backgroundOpacityKey = "NeiroBackgroundOpacity"

    /// 圆角强度（卡片 / 按钮 等共用的基础半径）
    public static let cornerRadiusKey = "NeiroCornerRadius"

    /// 动画速度倍率（0.5 = 慢一半，1.5 = 快一半）
    public static let animationSpeedKey = "NeiroAnimationSpeed"

    /// Home 副标题
    public static let homeSubtitleKey = "NeiroHomeSubtitle"
    public static let defaultHomeSubtitle = "Neiro·音色 - 离线播放器"

    /// 应用内语言
    public static let languageKey = "NeiroLanguage"

    /// 预设的强调色色板（含一个二次元向的樱花粉）
    public static let presets: [(name: String, color: Color)] = [
        ("系统蓝", .accentColor),
        ("樱花粉", Color(red: 1.00, green: 0.71, blue: 0.83)),
        ("天空青", Color(red: 0.45, green: 0.80, blue: 0.95)),
        ("薄荷绿", Color(red: 0.50, green: 0.85, blue: 0.70)),
        ("丁香紫", Color(red: 0.75, green: 0.65, blue: 0.93)),
        ("夕橙", Color(red: 1.00, green: 0.65, blue: 0.42))
    ]

    /// 把 Color 序列化为 hex 字符串存 UserDefaults
    public static func hex(from color: Color) -> String? {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = Int((nsColor.redComponent * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public static func color(fromHex hex: String) -> Color? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

public enum NeiroText {
    public static func tr(_ zh: String, _ en: String) -> String {
        let raw = UserDefaults.standard.string(forKey: NeiroTheme.languageKey) ?? NeiroLanguage.chinese.rawValue
        let language = NeiroLanguage(rawValue: raw) ?? .chinese
        return language == .english ? en : zh
    }
}
