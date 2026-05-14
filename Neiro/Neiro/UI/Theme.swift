
import SwiftUI


public extension View {

    func neiroGlass(cornerRadius: CGFloat = 16,
                    material: Material = .regularMaterial,
                    tint: Color? = nil) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, material: material, tint: tint))
    }

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


public enum NeiroTheme {
    public static let accentKey = "NeiroAccentColor"

    public static let appearanceKey = "NeiroAppearance"

    public static let backgroundImagePathKey = "NeiroBackgroundImagePath"

    public static let backgroundOpacityKey = "NeiroBackgroundOpacity"

    public static let backgroundEnabledKey = "NeiroBackgroundEnabled"

    public static let backgroundSizeRatioKey = "NeiroBackgroundSizeRatio"

    public static let copyOnImportKey = "NeiroCopyOnImport"

    public static let cornerRadiusKey = "NeiroCornerRadius"

    public static let animationSpeedKey = "NeiroAnimationSpeed"

    public static let homeSubtitleKey = "NeiroHomeSubtitle"
    public static let defaultHomeSubtitle = "Neiro·音色 - 离线播放器"

    public static let languageKey = "NeiroLanguage"

    public static let presets: [(name: String, color: Color)] = [
        ("系统蓝", .accentColor),
        ("樱花粉", Color(red: 1.00, green: 0.71, blue: 0.83)),
        ("天空青", Color(red: 0.45, green: 0.80, blue: 0.95)),
        ("薄荷绿", Color(red: 0.50, green: 0.85, blue: 0.70)),
        ("丁香紫", Color(red: 0.75, green: 0.65, blue: 0.93)),
        ("夕橙", Color(red: 1.00, green: 0.65, blue: 0.42))
    ]

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
