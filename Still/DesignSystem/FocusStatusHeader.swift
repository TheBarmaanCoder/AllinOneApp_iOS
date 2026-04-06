import SwiftUI

struct FocusStatusHeader: View {
    enum State {
        case idle
        case focusing(endsAt: Date)
    }

    let state: State

    init(isActive: Bool, endsAt: Date?) {
        if isActive, let endsAt {
            self.state = .focusing(endsAt: endsAt)
        } else {
            self.state = .idle
        }
    }

    init(state: State) {
        self.state = state
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            switch state {
            case .idle:
                Text("Focus")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                Text("Choose what to set aside, then begin.")
                    .font(.subheadline)
                    .foregroundStyle(Tokens.ColorName.textSecondary)
            case let .focusing(endsAt):
                Text("In focus")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                Text("Until \(endsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
