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

    // MARK: - Focus Mode messages (with emoji flair)

    private static let focusMessages: [(emoji: String, text: String)] = [
        ("🧘", "Your attention is the rarest thing you have. Give it to what matters."),
        ("🌊", "This urge will pass. What you build when you wait is yours."),
        ("⏳", "One clear hour beats a scattered day."),
        ("🌿", "Stillness is not empty — it is full of what you chose."),
        ("🏗️", "The life you want is built in moments like this one."),
        ("🪷", "You do not have to win every moment. Honor this one."),
        ("🔭", "Quiet focus is how hard things become simple."),
        ("🧠", "Discipline is remembering what you want long after wanting something else."),
        ("🌬️", "Breathe. The next right thing is often to stay where you are."),
        ("🚪", "Small boundaries today become freedom tomorrow."),
        ("🤫", "Shhh… this app is taking a nap. Let it rest."),
        ("📵", "This app can wait. Your goals can't."),
        ("🌙", "Even the moon takes a break from being full."),
        ("🐢", "Slow down. The scroll isn't going anywhere."),
        ("🎯", "Eyes on the prize, not the feed."),
    ]

    // MARK: - Still Mode messages

    private static let stillModeMessages: [(emoji: String, text: String)] = [
        ("🔒", "You chose Still Mode. This app is locked until you scan your QR code."),
        ("🌍", "Your phone is in Still Mode. The world outside is waiting for you."),
        ("🪨", "Still Mode is active. Put the phone down and come back when you're ready."),
        ("🤫", "This app is paused while you're in Still Mode. Enjoy the quiet."),
        ("✨", "Still Mode — the best things happen when you're not on your phone."),
    ]

    // MARK: - Shield builder

    private static func makeShield<T: Hashable>(copyKey: T) -> ShieldConfiguration {
        let defaults = UserDefaults(suiteName: "group.com.allinoneapp.still")
        let isStillMode = defaults?.bool(forKey: "stillModeActive") ?? false
        let isCheatActive = defaults?.bool(forKey: "stillCheatActive") ?? false

        let title = isStillMode ? "Still Mode" : "Focus Mode"

        let messages = isStillMode ? stillModeMessages : focusMessages
        let idx = abs(copyKey.hashValue) % messages.count
        let msg = messages[idx]

        let streak = readStreak(defaults: defaults)
        let streakLine = "\n\n🔥 \(streak)-day streak"

        let cheatLine: String
        if !isCheatActive {
            let remaining = readCheatRemaining(defaults: defaults)
            if remaining > 0 {
                if remaining < 60 {
                    let s = Int(ceil(remaining))
                    cheatLine = "\n⏱️ \(s)s cheat time left today"
                } else {
                    let mins = Int(remaining) / 60
                    cheatLine = "\n⏱️ \(mins)m cheat time left today"
                }
            } else {
                cheatLine = ""
            }
        } else {
            cheatLine = ""
        }

        let body = "\(msg.emoji) \(msg.text)\(streakLine)\(cheatLine)"

        let secondaryLabel: ShieldConfiguration.Label?
        if !isCheatActive {
            let remaining = readCheatRemaining(defaults: defaults)
            if remaining > 0 {
                let cheatButtonText: String
                if remaining < 60 {
                    let s = Int(ceil(remaining))
                    cheatButtonText = "Cheat (\(s)s left)"
                } else {
                    let mins = Int(remaining) / 60
                    cheatButtonText = "Cheat (\(mins)m left)"
                }
                secondaryLabel = ShieldConfiguration.Label(
                    text: cheatButtonText,
                    color: UIColor(white: 0.85, alpha: 1)
                )
            } else {
                secondaryLabel = ShieldConfiguration.Label(
                    text: "No cheat time left",
                    color: UIColor(white: 0.4, alpha: 1)
                )
            }
        } else {
            secondaryLabel = nil
        }

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: .black,
            icon: nil,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: body, color: UIColor(white: 0.75, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: secondaryLabel
        )
    }

    // MARK: - Helpers (read from shared UserDefaults without Core dependency)

    private static func readStreak(defaults: UserDefaults?) -> Int {
        guard let data = defaults?.data(forKey: "stillDailyFocusLog"),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return 0 }

        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current

        let today = cal.startOfDay(for: Date())
        let todayKey = fmt.string(from: today)
        let todayHas = (dict[todayKey] ?? 0) >= 1800
        guard todayHas else { return 0 }

        var check = today
        var streak = 0

        while true {
            let k = fmt.string(from: check)
            if (dict[k] ?? 0) >= 1800 {
                streak += 1
                check = cal.date(byAdding: .day, value: -1, to: check)!
            } else {
                break
            }
        }
        return streak
    }

    /// Mirrors app `CheatBudgetTracker.remainingSeconds()` (includes elapsed time during an active cheat).
    private static func readCheatRemaining(defaults: UserDefaults?) -> Double {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        let todayKey = fmt.string(from: Date())
        let storedDate = defaults?.string(forKey: "stillCheatDate") ?? ""
        if storedDate != todayKey { return 1800 }
        var used = defaults?.double(forKey: "stillCheatUsedSeconds") ?? 0
        if defaults?.bool(forKey: "stillCheatActive") == true {
            let startEpoch = defaults?.double(forKey: "stillCheatStart") ?? Date().timeIntervalSince1970
            used += Date().timeIntervalSince1970 - startEpoch
        }
        return max(0, 1800 - used)
    }
}
