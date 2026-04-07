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
                    .shadow(
                        color: StillTheme.current == .dark
                            ? Color.white.opacity(0.04)
                            : Color.black.opacity(0.06),
                        radius: 10, x: 0, y: 3
                    )
            )
    }
}
