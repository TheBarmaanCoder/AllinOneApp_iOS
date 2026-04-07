import SwiftUI

struct AlarmRingingView: View {
    let context: ActiveAlarmContext
    @ObservedObject var coordinator: AlarmRingingCoordinator
    @State private var scanMessage: String?
    @State private var didScanDismiss = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let mode = coordinator.successDismissMode {
                AlarmSuccessOverlay(dismissMode: mode) {
                    coordinator.dismissSuccessOverlay()
                }
            } else {
                challengeContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.successDismissMode != nil)
    }

    private var challengeContent: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            VStack(spacing: Tokens.Spacing.xs) {
                Text(ringingHeadline)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if !context.alarm.label.isEmpty {
                    Text(context.alarm.label)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }

            switch context.alarm.dismissMode.normalized {
            case .qr:
                qrContent
            default:
                simpleContent
            }
        }
        .padding(Tokens.Spacing.screenHorizontal)
    }

    private var ringingHeadline: String {
        switch context.alarm.dismissMode.normalized {
        case .qr:
            return context.alarm.label.isEmpty ? "Alarm" : context.alarm.label
        default:
            return "Good morning"
        }
    }

    // MARK: - Simple dismiss

    private var simpleContent: some View {
        VStack(spacing: Tokens.Spacing.xxl) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)

            Text("Tap below to stop the alarm")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            Button {
                coordinator.completeChallengeSuccessfully()
            } label: {
                Text("I'm up")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - QR dismiss

    private var qrContent: some View {
        VStack(spacing: Tokens.Spacing.lg) {
            Text("Scan your printed code")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Point the camera at the QR sticker you placed away from your bed.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            QRScannerRepresentable { text in
                guard !didScanDismiss else { return }
                Task {
                    let ok = await coordinator.validateQRPayload(text)
                    await MainActor.run {
                        if ok {
                            didScanDismiss = true
                            scanMessage = nil
                            coordinator.completeChallengeSuccessfully()
                        } else {
                            scanMessage = "That code did not match. Try again."
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous))

            if let scanMessage {
                Text(scanMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}
