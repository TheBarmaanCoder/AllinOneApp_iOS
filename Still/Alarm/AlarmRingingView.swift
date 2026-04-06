import SwiftUI

struct AlarmRingingView: View {
    let context: ActiveAlarmContext
    @ObservedObject var coordinator: AlarmRingingCoordinator
    @State private var scanMessage: String?
    @State private var didScanDismiss = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: Tokens.Spacing.xl) {
                VStack(spacing: Tokens.Spacing.xs) {
                    Text(ringingHeadline)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if shouldShowLabelUnderHeadline {
                        Text(context.alarm.label)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                }

                switch context.alarm.dismissMode {
                case .qr:
                    qrContent
                case .walk:
                    AlarmWalkDismissContent(fireDate: context.fireDate) {
                        coordinator.completeWalkDismiss()
                    }
                }
            }
            .padding(Tokens.Spacing.screenHorizontal)
        }
    }

    private var ringingHeadline: String {
        switch context.alarm.dismissMode {
        case .walk:
            return "Get up and walk"
        case .qr:
            return context.alarm.label.isEmpty ? "Alarm" : context.alarm.label
        }
    }

    private var shouldShowLabelUnderHeadline: Bool {
        context.alarm.dismissMode == .walk && !context.alarm.label.isEmpty
    }

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
                    let ok = await coordinator.handleScannedQRPayload(text)
                    await MainActor.run {
                        if ok {
                            didScanDismiss = true
                            scanMessage = nil
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
