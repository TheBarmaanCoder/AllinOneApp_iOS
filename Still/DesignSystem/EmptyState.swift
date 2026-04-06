import SwiftUI

struct EmptyState: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                Text(message)
                    .font(.body)
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton(title: actionTitle, action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
