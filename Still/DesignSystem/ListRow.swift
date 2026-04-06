import SwiftUI

struct ListRow: View {
    let title: String
    var subtitle: String?
    var showsChevron: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Tokens.ColorName.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }
        }
        .padding(.vertical, Tokens.Spacing.sm)
        .contentShape(Rectangle())
    }
}
