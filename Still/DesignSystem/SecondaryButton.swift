import SwiftUI

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            StillHaptics.lightImpact()
            action()
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                        .fill(Tokens.ColorName.surfaceMuted)
                )
                .foregroundStyle(Tokens.ColorName.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
