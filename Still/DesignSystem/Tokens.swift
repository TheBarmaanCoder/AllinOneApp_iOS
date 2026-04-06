import SwiftUI

/// Grayscale design tokens — black, white, and neutrals only.
enum Tokens {
    enum ColorName {
        static let backgroundPrimary = Color.stillBackground
        static let backgroundSecondary = Color.stillCard
        static let surfaceMuted = Color.stillMuted
        static let textPrimary = Color.stillText
        static let textSecondary = Color.stillTextSecondary
        static let textTertiary = Color.stillTextTertiary
        static let accent = Color.stillAccent
        static let accentSubtle = Color.stillAccentSubtle
        static let separator = Color.stillSeparator
        static let dangerMuted = Color.stillDanger
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

extension Color {
    static let stillBackground = Color(white: 0.98)
    static let stillCard = Color.white
    static let stillMuted = Color(white: 0.92)
    static let stillText = Color.black
    static let stillTextSecondary = Color(white: 0.45)
    static let stillTextTertiary = Color(white: 0.55)
    static let stillAccent = Color.black
    static let stillAccentSubtle = Color(white: 0.9)
    static let stillSeparator = Color.black.opacity(0.12)
    static let stillDanger = Color(white: 0.35)
}
