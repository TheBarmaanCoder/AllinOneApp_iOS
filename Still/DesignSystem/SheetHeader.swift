import SwiftUI

struct SheetHeader: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Tokens.ColorName.textPrimary)
            Spacer()
            Button("Done") { dismiss() }
                .font(.body.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.accent)
        }
        .padding(.bottom, Tokens.Spacing.sm)
    }
}
