import FamilyControls
import SwiftUI

struct SettingsViewScreen: View {
    private var status: AuthorizationStatus { FocusAuthorization.authorizationStatus() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                    Text("Settings")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Tokens.ColorName.textPrimary)

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

                    CalmCard {
                        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                            Text("How it works")
                                .font(.headline)
                                .foregroundStyle(Tokens.ColorName.textPrimary)
                            Text("Still applies shields only to what you pick. It cannot see content inside other apps. Ending focus in Still removes shields for this session; iOS may still allow changes from system settings.")
                                .font(.subheadline)
                                .foregroundStyle(Tokens.ColorName.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.vertical, Tokens.Spacing.screenVertical)
            }
            .background(Tokens.ColorName.backgroundPrimary.ignoresSafeArea())
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
