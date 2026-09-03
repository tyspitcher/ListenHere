// Defines stable theme identifiers, semantic palettes, backdrop treatments, and theme environment injection.

import SwiftUI

enum ThemeID: String, Codable, CaseIterable, Sendable {
    // Keep this persisted identifier stable even when the visual recipe evolves.
    case listenHere
    case system

    var theme: AppTheme {
        switch self {
        case .listenHere: .listenHere
        case .system: .system
        }
    }
}

struct AppPalette {
    let appBackground: Color
    let surface: Color
    let elevatedSurface: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let secondaryAccent: Color
    let tertiaryAccent: Color
    let destructive: Color
    let separator: Color
}

enum AppBackdropTreatment {
    case solid
    case image(assetName: String, opacity: Double)
}

struct AppTheme {
    let id: ThemeID
    let lightPalette: AppPalette
    let darkPalette: AppPalette
    let lightBackdrop: AppBackdropTreatment
    let darkBackdrop: AppBackdropTreatment

    func palette(for colorScheme: ColorScheme) -> AppPalette {
        colorScheme == .dark ? darkPalette : lightPalette
    }

    func backdrop(for colorScheme: ColorScheme) -> AppBackdropTreatment {
        colorScheme == .dark ? darkBackdrop : lightBackdrop
    }

    static let listenHere = AppTheme(
        id: .listenHere,
        lightPalette: AppPalette(
            appBackground: Color(red: 0.97, green: 0.95, blue: 0.91),
            surface: Color(red: 1.00, green: 0.99, blue: 0.97),
            elevatedSurface: .white,
            primaryText: Color(red: 0.09, green: 0.12, blue: 0.15),
            secondaryText: Color(red: 0.31, green: 0.35, blue: 0.37),
            accent: Color(red: 29 / 255, green: 92 / 255, blue: 138 / 255),
            secondaryAccent: Color(red: 32 / 255, green: 117 / 255, blue: 92 / 255),
            tertiaryAccent: Color(red: 148 / 255, green: 56 / 255, blue: 75 / 255),
            destructive: .red,
            separator: Color.black.opacity(0.12)
        ),
        darkPalette: AppPalette(
            appBackground: Color(red: 0.035, green: 0.075, blue: 0.105),
            surface: Color(red: 0.06, green: 0.14, blue: 0.19),
            elevatedSurface: Color(red: 0.08, green: 0.18, blue: 0.24),
            primaryText: Color(red: 0.97, green: 0.95, blue: 0.91),
            secondaryText: Color(red: 0.72, green: 0.78, blue: 0.80),
            accent: Color(red: 0.37, green: 0.66, blue: 0.84),
            secondaryAccent: Color(red: 0.35, green: 0.73, blue: 0.59),
            tertiaryAccent: Color(red: 0.86, green: 0.42, blue: 0.52),
            destructive: Color(red: 1.00, green: 0.35, blue: 0.32),
            separator: Color.white.opacity(0.14)
        ),
        lightBackdrop: .image(assetName: "WatercolorPaper", opacity: 0.72),
        darkBackdrop: .solid
    )

    static let system = AppTheme(
        id: .system,
        lightPalette: AppPalette(
            appBackground: Color(white: 0.96),
            surface: .white,
            elevatedSurface: .white,
            primaryText: .primary,
            secondaryText: .secondary,
            accent: .accentColor,
            secondaryAccent: .accentColor,
            tertiaryAccent: .accentColor,
            destructive: .red,
            separator: Color.black.opacity(0.12)
        ),
        darkPalette: AppPalette(
            appBackground: Color(white: 0.06),
            surface: Color(white: 0.12),
            elevatedSurface: Color(white: 0.16),
            primaryText: .primary,
            secondaryText: .secondary,
            accent: .accentColor,
            secondaryAccent: .accentColor,
            tertiaryAccent: .accentColor,
            destructive: .red,
            separator: Color.white.opacity(0.14)
        ),
        lightBackdrop: .solid,
        darkBackdrop: .solid
    )
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.listenHere
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension View {
    func appTheme(_ theme: AppTheme) -> some View {
        modifier(AppThemeModifier(theme: theme))
    }
}

private struct AppThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let theme: AppTheme

    func body(content: Content) -> some View {
        content
            .environment(\.appTheme, theme)
            .tint(theme.palette(for: colorScheme).accent)
    }
}
