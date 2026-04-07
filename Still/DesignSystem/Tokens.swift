import SwiftUI

// MARK: - Theme

enum StillTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    static var current: StillTheme {
        StillTheme(rawValue: UserDefaults.standard.string(forKey: "stillTheme") ?? "light") ?? .light
    }
}

// MARK: - Tokens

enum Tokens {
    enum ColorName {
        private static var theme: StillTheme { .current }

        static var backgroundPrimary: Color {
            theme == .dark ? Color(white: 0.07) : Color(white: 0.98)
        }

        static var backgroundSecondary: Color {
            theme == .dark ? Color(white: 0.13) : .white
        }

        static var surfaceMuted: Color {
            theme == .dark ? Color(white: 0.2) : Color(white: 0.92)
        }

        static var textPrimary: Color {
            theme == .dark ? Color(white: 0.95) : .black
        }

        static var textSecondary: Color {
            theme == .dark ? Color(white: 0.6) : Color(white: 0.45)
        }

        static var textTertiary: Color {
            theme == .dark ? Color(white: 0.45) : Color(white: 0.55)
        }

        static var accent: Color {
            theme == .dark ? .white : .black
        }

        static var accentSubtle: Color {
            theme == .dark ? Color(white: 0.18) : Color(white: 0.9)
        }

        static var separator: Color {
            theme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
        }

        static var dangerMuted: Color {
            theme == .dark ? Color(red: 0.9, green: 0.5, blue: 0.5) : Color(white: 0.35)
        }
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let screenHorizontal: CGFloat = 22
        static let screenVertical: CGFloat = 20
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 26
    }

    enum Motion {
        static let fast: Double = 0.2
        static let standard: Double = 0.28
    }
}
