import SwiftUI

struct ProPaywallSheet: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Tokens.ColorName.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Tokens.Spacing.xl) {
                    Spacer().frame(height: 20)

                    badge

                    headline

                    featuresList

                    purchaseButton

                    restoreButton

                    if let error = store.purchaseError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
                    .padding()
            }
        }
        .onChange(of: store.isProUnlocked) { unlocked in
            if unlocked { dismiss() }
        }
    }

    // MARK: - Badge

    private var badge: some View {
        ZStack {
            Circle()
                .fill(Tokens.ColorName.accent.opacity(0.1))
                .frame(width: 100, height: 100)
            Image(systemName: "star.fill")
                .font(.system(size: 44))
                .foregroundStyle(Tokens.ColorName.accent)
        }
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: Tokens.Spacing.xs) {
            Text("Still Pro")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Tokens.ColorName.textPrimary)

            Text("Unlock the full power of your QR code")
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorName.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featuresList: some View {
        VStack(spacing: 0) {
            featureRow(
                icon: "qrcode.viewfinder",
                title: "QR Alarm Dismiss",
                detail: "Force yourself out of bed — scan your printed QR code to stop the alarm."
            )
            Divider().background(Tokens.ColorName.separator).padding(.leading, 48)
            featureRow(
                icon: "moon.fill",
                title: "Still Mode",
                detail: "Scan to instantly block apps. Scan again and type a sentence to exit."
            )
            Divider().background(Tokens.ColorName.separator).padding(.leading, 48)
            featureRow(
                icon: "printer",
                title: "Print & Share QR",
                detail: "Generate, print, or AirDrop your personal QR code from Settings."
            )
        }
        .padding(Tokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                .fill(Tokens.ColorName.backgroundSecondary)
        )
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Tokens.ColorName.accent)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Tokens.Spacing.sm)
    }

    // MARK: - Purchase

    private var purchaseButton: some View {
        Button {
            Task { await store.purchase() }
        } label: {
            ZStack {
                Text(priceLabel)
                    .font(.headline)
                    .opacity(store.purchaseInProgress ? 0 : 1)
                if store.purchaseInProgress {
                    ProgressView()
                        .tint(Tokens.ColorName.backgroundPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                    .fill(Tokens.ColorName.accent)
            )
            .foregroundStyle(Tokens.ColorName.backgroundPrimary)
        }
        .buttonStyle(.plain)
        .disabled(store.purchaseInProgress)
    }

    private var priceLabel: String {
        if let product = store.proProduct {
            return "Unlock Still Pro — \(product.displayPrice)"
        }
        return "Unlock Still Pro — $2.99"
    }

    private var restoreButton: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            Text("Restore purchase")
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorName.textTertiary)
        }
        .disabled(store.purchaseInProgress)
    }
}
