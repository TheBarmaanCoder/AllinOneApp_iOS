import SwiftUI

struct CalmCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Tokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                    .fill(Tokens.ColorName.backgroundSecondary)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
            )
    }
}
