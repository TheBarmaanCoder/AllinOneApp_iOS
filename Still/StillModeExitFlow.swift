import SwiftUI

struct StillModeExitFlow: View {
    @ObservedObject var controller: StillModeController
    @State private var sentence = ""
    @State private var error: String?
    @State private var showSuccess = false
    @FocusState private var textFieldFocused: Bool

    private let expectedSentence = "I am getting out of Still Mode"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showSuccess {
                exitSuccessAnimation
            } else {
                exitForm
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSuccess)
    }

    private var exitForm: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.open.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.8))

            VStack(spacing: 8) {
                Text("Exit Still Mode")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Type the sentence below to confirm:")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(spacing: 12) {
                Text("\"\(expectedSentence)\"")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .italic()
                    .multilineTextAlignment(.center)

                TextField("", text: $sentence)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
                    .focused($textFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit { confirmExit() }
            }
            .padding(.horizontal, 32)

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Button {
                confirmExit()
            } label: {
                Text("Confirm")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: 240)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                controller.cancelExit()
            } label: {
                Text("Stay in Still Mode")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .onAppear { textFieldFocused = true }
    }

    private var exitSuccessAnimation: some View {
        StillModeExitSuccessView {
            controller.syncFromStore()
        }
    }

    private func confirmExit() {
        if controller.confirmExit(sentence: sentence) {
            StillHaptics.success()
            withAnimation { showSuccess = true }
        } else {
            error = "That doesn't match. Please type the exact sentence."
            StillHaptics.warning()
        }
    }
}

// MARK: - Exit success animation

private struct StillModeExitSuccessView: View {
    var onDone: () -> Void

    @State private var phase: Phase = .lock

    private enum Phase {
        case lock, morph, sun, done
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.6), lineWidth: 4)
                    .frame(width: 120, height: 120)
                    .scaleEffect(phase == .lock ? 0.5 : 1)
                    .opacity(phase == .lock ? 0 : 1)

                Group {
                    if phase == .sun || phase == .done {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(.orange)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: phase)

            VStack {
                Spacer()
                Text(phase == .sun || phase == .done ? "Still Mode ended" : "")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .opacity(phase == .sun || phase == .done ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: phase)
                    .padding(.bottom, 80)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            phase = .morph
            StillHaptics.success()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            phase = .sun
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            phase = .done
            onDone()
        }
    }
}
