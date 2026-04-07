import FamilyControls
import SwiftUI
import UIKit

private struct QRSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct SettingsViewScreen: View {
    private var status: AuthorizationStatus { FocusAuthorization.authorizationStatus() }
    @State private var qrSharePayload: QRSharePayload?
    @AppStorage("stillTheme") private var themeRaw: String = StillTheme.light.rawValue

    private var selectedTheme: StillTheme {
        get { StillTheme(rawValue: themeRaw) ?? .light }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                    Text("Settings")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Tokens.ColorName.textPrimary)

                    themeCard

                    qrCard

                    howToUseCard

                    CalmCard {
                        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                            Text("Screen Time")
                                .font(.headline)
                                .foregroundStyle(Tokens.ColorName.textPrimary)
                            Text(statusText)
                                .font(.subheadline)
                                .foregroundStyle(Tokens.ColorName.textSecondary)
                            Text("You can change access anytime in Settings → Screen Time → Still.")
                                .font(.footnote)
                                .foregroundStyle(Tokens.ColorName.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.vertical, Tokens.Spacing.screenVertical)
            }
            .background(Tokens.ColorName.backgroundPrimary.ignoresSafeArea())
        }
        .sheet(item: $qrSharePayload) { payload in
            ActivityShareSheet(activityItems: [payload.image])
        }
    }

    // MARK: - Theme

    private var themeCard: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                Label("Appearance", systemImage: "paintbrush")
                    .font(.headline)
                    .foregroundStyle(Tokens.ColorName.textPrimary)

                HStack(spacing: Tokens.Spacing.sm) {
                    ForEach(StillTheme.allCases) { theme in
                        themeChip(theme)
                    }
                }
            }
        }
    }

    private func themeChip(_ theme: StillTheme) -> some View {
        let isSelected = selectedTheme == theme
        return Button {
            StillHaptics.selectionChanged()
            withAnimation(.easeInOut(duration: 0.25)) {
                themeRaw = theme.rawValue
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(chipBackground(for: theme))
                        .frame(height: 48)

                    Image(systemName: theme.systemImage)
                        .font(.body.weight(.medium))
                        .foregroundStyle(chipForeground(for: theme))
                }

                Text(theme.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? Tokens.ColorName.textPrimary : Tokens.ColorName.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Tokens.ColorName.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func chipBackground(for theme: StillTheme) -> Color {
        switch theme {
        case .light: return Color(white: 0.95)
        case .dark: return Color(white: 0.12)
        }
    }

    private func chipForeground(for theme: StillTheme) -> Color {
        switch theme {
        case .light: return .black
        case .dark: return .white
        }
    }

    // MARK: - QR Card

    private var qrCard: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                Label("Your QR Code", systemImage: "qrcode")
                    .font(.headline)
                    .foregroundStyle(Tokens.ColorName.textPrimary)

                Text("Print this code or save it. Place it away from your bed.")
                    .font(.subheadline)
                    .foregroundStyle(Tokens.ColorName.textSecondary)

                HStack {
                    Spacer()
                    QRCodeImageView(content: AlarmQRTokenStore.dismissURLString, dimension: 180)
                    Spacer()
                }

                SecondaryButton(title: "Share / Print QR") {
                    let url = AlarmQRTokenStore.dismissURLString
                    if let image = QRCodeImageView.qrUIImage(content: url, dimension: 768) {
                        StillHaptics.lightImpact()
                        qrSharePayload = QRSharePayload(image: image)
                    }
                }
            }
        }
    }

    // MARK: - How to use

    private var howToUseCard: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                Label("How to use your QR code", systemImage: "info.circle")
                    .font(.headline)
                    .foregroundStyle(Tokens.ColorName.textPrimary)

                VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                    usageRow(
                        icon: "alarm",
                        title: "Dismiss QR alarms",
                        detail: "When a QR alarm rings, open the app and scan this code to stop it."
                    )
                    Divider()
                    usageRow(
                        icon: "moon.fill",
                        title: "Enter Still Mode",
                        detail: "Point your iPhone camera at this code to instantly block apps. Scan again and type a sentence to exit."
                    )
                    Divider()
                    usageRow(
                        icon: "printer",
                        title: "Print & place",
                        detail: "Print the code or save it somewhere away from your bed. Tap Share above to AirDrop, print, or save."
                    )
                }
            }
        }
    }

    private func usageRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Tokens.ColorName.textTertiary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusText: String {
        switch status {
        case .approved:
            return "Connected"
        case .denied:
            return "Not approved"
        case .notDetermined:
            return "Not yet requested"
        default:
            return "Unknown"
        }
    }
}
