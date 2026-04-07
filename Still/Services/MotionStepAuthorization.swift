import CoreMotion
import Foundation

/// Ensures `resume()` runs at most once (CMPedometer callbacks are not guaranteed on all OS paths).
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<Void, Never>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume()
    }
}

/// Triggers the system Motion & Fitness prompt (needed for walk-to-dismiss alarms).
enum MotionStepAuthorization {
    static func status() -> CMAuthorizationStatus {
        CMPedometer.authorizationStatus()
    }

    static var isStepCountingAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    /// Satisfied when step counting is not available (e.g. Simulator) or access is authorized.
    static var isSatisfiedForApp: Bool {
        !isStepCountingAvailable || status() == .authorized
    }

    /// First query triggers the permission sheet when status is `notDetermined`.
    static func requestAccess() async {
        guard isStepCountingAvailable else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = ResumeOnce(continuation)
            let pedometer = CMPedometer()
            let end = Date()
            let start = end.addingTimeInterval(-120)
            pedometer.queryPedometerData(from: start, to: end) { _, _ in
                once.resume()
            }
            // `queryPedometerData` sometimes never invokes the handler (permission UI, app transitions).
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                once.resume()
            }
        }
    }
}
