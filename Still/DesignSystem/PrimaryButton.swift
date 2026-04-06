import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            if !isDisabled, !isLoading {
                StillHaptics.lightImpact()
            }
            action()
        } label: {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                    .fill(Tokens.ColorName.accent)
            )
            .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled || isLoading ? 0.55 : 1)
    }
}
