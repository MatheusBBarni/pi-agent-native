import SwiftUI
import AppKit

public enum Theme {
    static var windowBackground: Color { Color(hex: palette.windowBackground) }
    public static var appBackground: Color { Color(hex: palette.appBackground) }
    static var sidebarBackground: Color { Color(hex: palette.sidebarBackground) }
    static var sidebarSelection: Color { Color(hex: palette.sidebarSelection) }
    static var panelBackground: Color { Color(hex: palette.panelBackground) }
    static var composerBackground: Color { Color(hex: palette.composerBackground) }
    static var elevatedBackground: Color { Color(hex: palette.elevatedBackground) }
    static var userMessageBackground: Color { Color(hex: palette.userMessageBackground) }
    static var assistantMessageBackground: Color { Color(hex: palette.assistantMessageBackground) }
    static var border: Color { Color(hex: palette.border, opacity: palette.borderOpacity) }
    static var primaryText: Color { Color(hex: palette.primaryText) }
    static var secondaryText: Color { Color(hex: palette.secondaryText) }
    static var tertiaryText: Color { Color(hex: palette.tertiaryText) }
    static var accent: Color { Color(hex: palette.accent) }
    static var green: Color { Color(hex: palette.green) }
    static var red: Color { Color(hex: palette.red) }

    private static var palette: ThemePalette {
        let defaults = UserDefaults.standard
        let family = defaults.string(forKey: "themeFamily").flatMap(AppThemeFamily.init(rawValue:)) ?? .nord
        let variant = defaults.string(forKey: "themeVariant").flatMap(AppThemeVariant.init(rawValue:)) ?? .dark
        return ThemePalette.palette(for: family, variant: variant)
    }
}

private struct ThemePalette {
    var windowBackground: UInt
    var appBackground: UInt
    var sidebarBackground: UInt
    var sidebarSelection: UInt
    var panelBackground: UInt
    var composerBackground: UInt
    var elevatedBackground: UInt
    var userMessageBackground: UInt
    var assistantMessageBackground: UInt
    var border: UInt
    var borderOpacity: Double
    var primaryText: UInt
    var secondaryText: UInt
    var tertiaryText: UInt
    var accent: UInt
    var green: UInt
    var red: UInt

    static func palette(for family: AppThemeFamily, variant: AppThemeVariant) -> ThemePalette {
        switch (family, variant) {
        case (.nord, .dark):
            ThemePalette(
                windowBackground: 0x2E3440,
                appBackground: 0x2E3440,
                sidebarBackground: 0x3B4252,
                sidebarSelection: 0x434C5E,
                panelBackground: 0x3B4252,
                composerBackground: 0x434C5E,
                elevatedBackground: 0x4C566A,
                userMessageBackground: 0x5E81AC,
                assistantMessageBackground: 0x3B4252,
                border: 0xD8DEE9,
                borderOpacity: 0.12,
                primaryText: 0xECEFF4,
                secondaryText: 0xD8DEE9,
                tertiaryText: 0xA7B1C2,
                accent: 0x88C0D0,
                green: 0xA3BE8C,
                red: 0xBF616A
            )
        case (.nord, .light):
            ThemePalette(
                windowBackground: 0xECEFF4,
                appBackground: 0xECEFF4,
                sidebarBackground: 0xE5E9F0,
                sidebarSelection: 0xD8DEE9,
                panelBackground: 0xE5E9F0,
                composerBackground: 0xD8DEE9,
                elevatedBackground: 0xD8DEE9,
                userMessageBackground: 0x5E81AC,
                assistantMessageBackground: 0xE5E9F0,
                border: 0x2E3440,
                borderOpacity: 0.12,
                primaryText: 0x2E3440,
                secondaryText: 0x4C566A,
                tertiaryText: 0x5E81AC,
                accent: 0x5E81AC,
                green: 0x4F7D3F,
                red: 0xBF616A
            )
        case (.dracula, .dark):
            ThemePalette(
                windowBackground: 0x282A36,
                appBackground: 0x282A36,
                sidebarBackground: 0x21222C,
                sidebarSelection: 0x44475A,
                panelBackground: 0x343746,
                composerBackground: 0x44475A,
                elevatedBackground: 0x424450,
                userMessageBackground: 0x644AC9,
                assistantMessageBackground: 0x343746,
                border: 0xF8F8F2,
                borderOpacity: 0.10,
                primaryText: 0xF8F8F2,
                secondaryText: 0xCFCFE2,
                tertiaryText: 0x6272A4,
                accent: 0xBD93F9,
                green: 0x50FA7B,
                red: 0xFF5555
            )
        case (.dracula, .light):
            ThemePalette(
                windowBackground: 0xFFFBEB,
                appBackground: 0xFFFBEB,
                sidebarBackground: 0xECE9DF,
                sidebarSelection: 0xDEDCCF,
                panelBackground: 0xECE9DF,
                composerBackground: 0xDEDCCF,
                elevatedBackground: 0xCECCC0,
                userMessageBackground: 0x644AC9,
                assistantMessageBackground: 0xECE9DF,
                border: 0x1F1F1F,
                borderOpacity: 0.12,
                primaryText: 0x1F1F1F,
                secondaryText: 0x4B4637,
                tertiaryText: 0x6C664B,
                accent: 0x644AC9,
                green: 0x14710A,
                red: 0xCB3A2A
            )
        case (.catppuccin, .dark):
            ThemePalette(
                windowBackground: 0x1E1E2E,
                appBackground: 0x1E1E2E,
                sidebarBackground: 0x181825,
                sidebarSelection: 0x313244,
                panelBackground: 0x181825,
                composerBackground: 0x313244,
                elevatedBackground: 0x45475A,
                userMessageBackground: 0x1E66F5,
                assistantMessageBackground: 0x313244,
                border: 0xCDD6F4,
                borderOpacity: 0.10,
                primaryText: 0xCDD6F4,
                secondaryText: 0xBAC2DE,
                tertiaryText: 0xA6ADC8,
                accent: 0x89B4FA,
                green: 0xA6E3A1,
                red: 0xF38BA8
            )
        case (.catppuccin, .light):
            ThemePalette(
                windowBackground: 0xEFF1F5,
                appBackground: 0xEFF1F5,
                sidebarBackground: 0xE6E9EF,
                sidebarSelection: 0xCCD0DA,
                panelBackground: 0xE6E9EF,
                composerBackground: 0xCCD0DA,
                elevatedBackground: 0xBCC0CC,
                userMessageBackground: 0x1E66F5,
                assistantMessageBackground: 0xE6E9EF,
                border: 0x4C4F69,
                borderOpacity: 0.12,
                primaryText: 0x4C4F69,
                secondaryText: 0x5C5F77,
                tertiaryText: 0x7C7F93,
                accent: 0x1E66F5,
                green: 0x40A02B,
                red: 0xD20F39
            )
        case (.one, .dark):
            ThemePalette(
                windowBackground: 0x282C34,
                appBackground: 0x282C34,
                sidebarBackground: 0x21252B,
                sidebarSelection: 0x3A3F4B,
                panelBackground: 0x21252B,
                composerBackground: 0x3A3F4B,
                elevatedBackground: 0x4B5263,
                userMessageBackground: 0x4078F2,
                assistantMessageBackground: 0x2F343D,
                border: 0xABB2BF,
                borderOpacity: 0.10,
                primaryText: 0xABB2BF,
                secondaryText: 0x828997,
                tertiaryText: 0x5C6370,
                accent: 0x61AFEF,
                green: 0x98C379,
                red: 0xE06C75
            )
        case (.one, .light):
            ThemePalette(
                windowBackground: 0xFAFAFA,
                appBackground: 0xFAFAFA,
                sidebarBackground: 0xF0F1F4,
                sidebarSelection: 0xE5E5E6,
                panelBackground: 0xF0F1F4,
                composerBackground: 0xE5E5E6,
                elevatedBackground: 0xD7DAE0,
                userMessageBackground: 0x4078F2,
                assistantMessageBackground: 0xF0F1F4,
                border: 0x383A42,
                borderOpacity: 0.12,
                primaryText: 0x383A42,
                secondaryText: 0x696C77,
                tertiaryText: 0xA0A1A7,
                accent: 0x4078F2,
                green: 0x50A14F,
                red: 0xE45649
            )
        case (.nightOwl, .dark):
            ThemePalette(
                windowBackground: 0x011627,
                appBackground: 0x011627,
                sidebarBackground: 0x001122,
                sidebarSelection: 0x1D3B53,
                panelBackground: 0x01111D,
                composerBackground: 0x0B253A,
                elevatedBackground: 0x0B2942,
                userMessageBackground: 0x7E57C2,
                assistantMessageBackground: 0x0B253A,
                border: 0xD6DEEB,
                borderOpacity: 0.10,
                primaryText: 0xD6DEEB,
                secondaryText: 0x89A4BB,
                tertiaryText: 0x5F7E97,
                accent: 0x82AAFF,
                green: 0xC5E478,
                red: 0xEF5350
            )
        case (.nightOwl, .light):
            ThemePalette(
                windowBackground: 0xFBFBFB,
                appBackground: 0xFBFBFB,
                sidebarBackground: 0xF0F0F0,
                sidebarSelection: 0xD3E8F8,
                panelBackground: 0xF6F6F6,
                composerBackground: 0xF0F0F0,
                elevatedBackground: 0xE0E7EA,
                userMessageBackground: 0x0C969B,
                assistantMessageBackground: 0xF6F6F6,
                border: 0x403F53,
                borderOpacity: 0.12,
                primaryText: 0x403F53,
                secondaryText: 0x697098,
                tertiaryText: 0x989FB1,
                accent: 0x2AA298,
                green: 0x08916A,
                red: 0xD3423E
            )
        }
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xff) / 255
        let green = Double((hex >> 8) & 0xff) / 255
        let blue = Double(hex & 0xff) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension Color {
    init(light: UInt, dark: UInt, lightOpacity: Double = 1, darkOpacity: Double = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            let hex = bestMatch == .darkAqua ? dark : light
            let opacity = bestMatch == .darkAqua ? darkOpacity : lightOpacity
            return NSColor(hex: hex, opacity: opacity)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt, opacity: Double = 1) {
        let red = CGFloat((hex >> 16) & 0xff) / 255
        let green = CGFloat((hex >> 8) & 0xff) / 255
        let blue = CGFloat(hex & 0xff) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: CGFloat(opacity))
    }
}

private struct UIFontSizeKey: EnvironmentKey {
    static let defaultValue = 15.0
}

extension EnvironmentValues {
    var uiFontSize: Double {
        get { self[UIFontSizeKey.self] }
        set { self[UIFontSizeKey.self] = newValue }
    }
}

private struct ScaledUIFontModifier: ViewModifier {
    @Environment(\.uiFontSize) private var uiFontSize
    let size: CGFloat
    let weight: Font.Weight?
    let design: Font.Design?

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }

    private var scaledSize: CGFloat {
        size * CGFloat(uiFontSize / 15)
    }
}

extension View {
    func uiFont(size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil) -> some View {
        modifier(ScaledUIFontModifier(size: size, weight: weight, design: design))
    }
}

struct SmallCapsLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .uiFont(size: 12, weight: .medium)
            .foregroundStyle(Theme.secondaryText)
            .textCase(.uppercase)
            .tracking(0)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.primaryText : Theme.secondaryText)
            .frame(width: 30, height: 30)
            .background(configuration.isPressed ? Theme.elevatedBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
