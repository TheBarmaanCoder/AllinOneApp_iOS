import UIKit

/// Native-style haptics: light impacts for taps, selection for picker ticks.
enum StillHaptics {
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func softImpact() {
        if #available(iOS 17.0, *) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    static func rigidImpact() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// Matches scroll wheel / picker detents.
    static func selectionChanged() {
        let g = UISelectionFeedbackGenerator()
        g.prepare()
        g.selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
