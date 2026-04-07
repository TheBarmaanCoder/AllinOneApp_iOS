@preconcurrency import CoreMotion
import SwiftUI

struct AlarmWalkDismissContent: View {
    let fireDate: Date
    var onComplete: () -> Void

    @State private var steps: Int = 0
    @State private var errorText: String?
    @State private var timer: Timer?
    @State private var pedometer: CMPedometer?

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
        .task { await startCounting() }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startCounting() async {
        guard CMPedometer.isStepCountingAvailable() else {
            errorText = "Step counting needs a physical iPhone with Motion & Fitness enabled."
            return
        }

        let ped = CMPedometer()
        pedometer = ped

        // Immediate check — user may have already walked before opening the app
        let alreadyDone = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            ped.queryPedometerData(from: fireDate, to: Date()) { data, _ in
                let n = data?.numberOfSteps.intValue ?? 0
                DispatchQueue.main.async { steps = n }
                cont.resume(returning: n >= required)
            }
        }
        if alreadyDone {
            onComplete()
            return
        }

        // Live updates via startUpdates for faster response
        ped.startUpdates(from: fireDate) { data, error in
            DispatchQueue.main.async {
                if let error {
                    errorText = error.localizedDescription
                    return
                }
                let n = data?.numberOfSteps.intValue ?? 0
                steps = n
                if n >= required {
                    ped.stopUpdates()
                    timer?.invalidate()
                    timer = nil
                    onComplete()
                }
            }
        }

        // Polling fallback in case live updates stall
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            ped.queryPedometerData(from: fireDate, to: Date()) { data, _ in
                DispatchQueue.main.async {
                    let n = data?.numberOfSteps.intValue ?? 0
                    steps = max(steps, n)
                    if n >= required {
                        ped.stopUpdates()
                        timer?.invalidate()
                        timer = nil
                        onComplete()
                    }
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
