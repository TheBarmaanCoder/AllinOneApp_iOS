import SwiftUI

struct BreakFocusFlowView: View {
    var onFinished: () -> Void

    @EnvironmentObject private var session: FocusSessionController
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 0
    @State private var phrase: String = ""
    @State private var countdown: Int = 30
    @State private var timerActive = false

    private let expectedPhrase = "I choose to break focus"

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0:
                    explainStep
                case 1:
                    phraseStep
                case 2:
                    waitStep
                default:
                    finalStep
                }
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
            .padding(.vertical, Tokens.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Tokens.ColorName.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Break focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        StillHaptics.softImpact()
                        dismiss()
                        onFinished()
                    }
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                }
            }
        }
    }

    private var explainStep: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
            Text("Leaving focus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textPrimary)
            Text("This removes Still’s shields for this session. It does not change other Screen Time settings you may have in iOS.")
                .font(.body)
                .foregroundStyle(Tokens.ColorName.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Continue") {
                step = 1
            }
        }
    }

    private var phraseStep: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            Text("Type the sentence below.")
                .font(.headline)
                .foregroundStyle(Tokens.ColorName.textPrimary)
            Text("“\(expectedPhrase)”")
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorName.textSecondary)
                .italic()
            TextField("Type here", text: $phrase)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
            PrimaryButton(
                title: "Continue",
                isDisabled: phrase.trimmingCharacters(in: .whitespacesAndNewlines) != expectedPhrase
            ) {
                step = 2
                startCountdown()
            }
        }
    }

    private var waitStep: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            Text("Brief pause")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textPrimary)
            Text("A short moment to be sure. You can leave this screen open.")
                .font(.body)
                .foregroundStyle(Tokens.ColorName.textSecondary)
            Text(timerActive ? "\(countdown)s" : "…")
                .font(.system(.largeTitle, design: .default).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Tokens.ColorName.textPrimary)
                .padding(.vertical, Tokens.Spacing.md)
        }
        .onAppear {
            if !timerActive { startCountdown() }
        }
    }

    private var finalStep: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
            Text("End this session")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textPrimary)
            Text("Shields from Still will clear. Time already spent in this session is kept in your calm tally.")
                .font(.body)
                .foregroundStyle(Tokens.ColorName.textSecondary)
            PrimaryButton(title: "End focus", action: endSession)
            SecondaryButton(title: "Go back") {
                step = 0
                phrase = ""
                timerActive = false
            }
        }
    }

    private func startCountdown() {
        timerActive = true
        countdown = 30
        Task {
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    countdown -= 1
                    if countdown > 0 {
                        StillHaptics.selectionChanged()
                    }
                    if countdown == 0 {
                        step = 3
                        timerActive = false
                        StillHaptics.warning()
                    }
                }
            }
        }
    }

    private func endSession() {
        session.breakFocusEarly()
        StillHaptics.success()
        dismiss()
        onFinished()
    }
}
