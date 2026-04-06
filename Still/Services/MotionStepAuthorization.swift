import CoreMotion
import Foundation

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
        await withCheckedContinuation { continuation in
            guard isStepCountingAvailable else {
                continuation.resume()
                return
            }
            let pedometer = CMPedometer()
            let end = Date()
            let start = end.addingTimeInterval(-120)
            pedometer.queryPedometerData(from: start, to: end) { _, _ in
                continuation.resume()
            }
        }
    }
}
