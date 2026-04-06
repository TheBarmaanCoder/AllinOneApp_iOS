import CoreMotion
import SwiftUI

struct AlarmWalkDismissContent: View {
    let fireDate: Date
    var onComplete: () -> Void

    @State private var steps: Int = 0
    @State private var errorText: String?
    @State private var timer: Timer?

    private let required = AlarmConstants.requiredSteps

    var body: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            Text("Walk \(required) steps")
                .font(.title2.weight(.semibold))
            Text("Counted from when the alarm fired.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.75))
                .multilineTextAlignment(.center)

            Text("\(steps) / \(required)")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .onAppear { startPolling() }
        .onDisappear { timer?.invalidate() }
    }

    private func startPolling() {
        guard CMPedometer.isStepCountingAvailable() else {
            errorText = "Step counting needs a physical iPhone with Motion & Fitness enabled."
            return
        }

        let pedometer = CMPedometer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            pedometer.queryPedometerData(from: fireDate, to: Date()) { data, error in
                DispatchQueue.main.async {
                    if let error {
                        errorText = error.localizedDescription
                        return
                    }
                    let n = data?.numberOfSteps.intValue ?? 0
                    steps = n
                    if n >= required {
                        timer?.invalidate()
                        timer = nil
                        StillHaptics.success()
                        onComplete()
                    }
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
        timer?.fire()
    }
}
