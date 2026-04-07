import FamilyControls
import SwiftUI
import UIKit

private struct QRSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct SettingsViewScreen: View {
    private var status: AuthorizationStatus { FocusAuthorization.authorizationStatus() }
    @EnvironmentObject private var store: StoreManager
    @State private var qrSharePayload: QRSharePayload?
    @State private var showPaywall = false
    @State private var showRedeemAlert = false
    @State private var redeemCode = ""
    @State private var redeemError = false
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

                    proCard

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

                    restoreRow

                    redeemRow
                }
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.vertical, Tokens.Spacing.screenVertical)
            }
            .background(Tokens.ColorName.backgroundPrimary.ignoresSafeArea())
        }
        .sheet(item: $qrSharePayload) { payload in
            ActivityShareSheet(activityItems: [payload.image])
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallSheet()
        }
        .alert("Redeem code", isPresented: $showRedeemAlert) {
            TextField("Secret password", text: $redeemCode)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Redeem") {
                if redeemCode == "Soleil2016" {
                    store.redeemProAccess()
                    redeemCode = ""
                } else {
                    redeemError = true
                    redeemCode = ""
                }
            }
            Button("Cancel", role: .cancel) {
                redeemCode = ""
            }
        } message: {
            Text("Enter your secret password to unlock Still Pro.")
        }
        .alert("Invalid code", isPresented: $redeemError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("That code is not valid. Try again.")
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

    // MARK: - Pro Card

    private var proCard: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                HStack {
                    Image(systemName: store.isProUnlocked ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(store.isProUnlocked ? Color.orange : Tokens.ColorName.textTertiary)
                    Text("Still Pro")
                        .font(.headline)
                        .foregroundStyle(Tokens.ColorName.textPrimary)
                    Spacer()
                    if store.isProUnlocked {
                        Text("Unlocked")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }

                if store.isProUnlocked {
                    Text("You have full access to QR alarms, Still Mode, and QR printing.")
                        .font(.subheadline)
                        .foregroundStyle(Tokens.ColorName.textSecondary)
                } else {
                    Text("Unlock QR alarm dismiss, Still Mode, and QR code printing with a one-time purchase.")
                        .font(.subheadline)
                        .foregroundStyle(Tokens.ColorName.textSecondary)

                    PrimaryButton(title: "Unlock Still Pro") {
                        showPaywall = true
                    }
                }
            }
        }
    }

    // MARK: - QR Card

    private var qrCard: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                HStack {
                    Label("Your QR Code", systemImage: "qrcode")
                        .font(.headline)
                        .foregroundStyle(Tokens.ColorName.textPrimary)
                    if !store.isProUnlocked {
                        Spacer()
                        proBadge
                    }
                }

                Text("Print this code or save it. Place it away from your bed.")
                    .font(.subheadline)
                    .foregroundStyle(Tokens.ColorName.textSecondary)

                if store.isProUnlocked {
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
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: Tokens.Spacing.sm) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Tokens.ColorName.textTertiary)
                            Text("Unlock Still Pro to view and share your QR code")
                                .font(.footnote)
                                .foregroundStyle(Tokens.ColorName.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, Tokens.Spacing.xl)
                        Spacer()
                    }

                    SecondaryButton(title: "Unlock Still Pro") {
                        showPaywall = true
                    }
                }
            }
        }
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.orange))
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

    // MARK: - Redeem code

    private var redeemRow: some View {
        Button {
            showRedeemAlert = true
        } label: {
            Text("Redeem code")
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorName.textTertiary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Restore purchases

    private var restoreRow: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            Text("Restore purchases")
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorName.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .disabled(store.purchaseInProgress)
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
