import SwiftUI

struct StatBlock: View {
    let title: String
    let value: String
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorName.textSecondary)
            Text(value)
                .font(.system(.title, design: .default))
                .fontWeight(.semibold)
                .foregroundStyle(Tokens.ColorName.textPrimary)
                .monospacedDigit()
            if let footnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
