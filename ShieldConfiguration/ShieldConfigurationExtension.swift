import ManagedSettings
import ManagedSettingsUI
import UIKit

@objc(ShieldConfigurationExtension)
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        Self.makeShield(copyKey: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        Self.makeShield(copyKey: webDomain)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        Self.makeShield(copyKey: application)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        Self.makeShield(copyKey: webDomain)
    }

    private static let focusMessages: [String] = [
        "Your attention is the rarest thing you have. Give it to what matters.",
        "This urge will pass. What you build when you wait is yours.",
        "One clear hour beats a scattered day.",
        "Stillness is not empty—it is full of what you chose.",
        "The life you want is built in moments like this one.",
        "You do not have to win every moment. You only have to honor this one.",
        "Quiet focus is how hard things become simple.",
        "Discipline is remembering what you want long after wanting something else.",
        "Breathe. The next right thing is often to stay where you are.",
        "Small boundaries today become freedom tomorrow.",
    ]

    private static let stillModeMessages: [String] = [
        "You chose Still Mode. This app is locked until you scan your QR code.",
        "Your phone is in Still Mode. The world outside is waiting for you.",
        "Still Mode is active. Put the phone down and come back when you're ready.",
        "This app is paused while you're in Still Mode. Enjoy the quiet.",
        "Still Mode — the best things happen when you're not on your phone.",
    ]

    private static func makeShield<T: Hashable>(copyKey: T) -> ShieldConfiguration {
        let isStillMode = UserDefaults(suiteName: "group.com.allinoneapp.still")?.bool(forKey: "stillModeActive") ?? false
        let messages = isStillMode ? stillModeMessages : focusMessages
        let title = isStillMode ? "Still Mode" : "Focus Mode"
        let idx = abs(copyKey.hashValue) % messages.count
        let body = messages[idx]
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: .black,
            icon: nil,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: body, color: UIColor(white: 0.75, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .black),
            primaryButtonBackgroundColor: .white
        )
    }
}
