import Foundation

// MARK: - Achievement definition

struct StillAchievement: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    /// SF Symbol name for the locked silhouette.
    let lockedIcon: String
    /// SF Symbol name for the unlocked collectible.
    let unlockedIcon: String
    let category: Category
    let threshold: Int

    enum Category: String {
        case streak
        case focusHours
    }
}

// MARK: - Catalog

enum AchievementCatalog {
    static let all: [StillAchievement] = streakAchievements + focusAchievements

    /// Shelf-only tile: never unlocks. Shows users what locked collectibles look like before they earn one.
    static let unknownMystery: StillAchievement = .init(
        id: "unknown",
        title: "Unknown",
        detail: "Locked collectibles look like this until you earn them.",
        lockedIcon: "questionmark.circle.fill",
        unlockedIcon: "questionmark.circle.fill",
        category: .streak,
        threshold: Int.max
    )

    static let streakAchievements: [StillAchievement] = [
        .init(id: "streak_3",   title: "New Moon",        detail: "3-day streak",    lockedIcon: "moon",            unlockedIcon: "moon.fill",              category: .streak, threshold: 3),
        .init(id: "streak_7",   title: "Waxing Crescent", detail: "7-day streak",    lockedIcon: "moon",            unlockedIcon: "moonphase.waxing.crescent",   category: .streak, threshold: 7),
        .init(id: "streak_14",  title: "First Quarter",   detail: "14-day streak",   lockedIcon: "moon",            unlockedIcon: "moonphase.first.quarter",     category: .streak, threshold: 14),
        .init(id: "streak_30",  title: "Waxing Gibbous",  detail: "30-day streak",   lockedIcon: "moon",            unlockedIcon: "moonphase.waxing.gibbous",    category: .streak, threshold: 30),
        .init(id: "streak_60",  title: "Full Moon",       detail: "60-day streak",   lockedIcon: "moon",            unlockedIcon: "moon.fill",              category: .streak, threshold: 60),
        .init(id: "streak_100", title: "Supermoon",       detail: "100-day streak",  lockedIcon: "moon",            unlockedIcon: "moon.stars.fill",        category: .streak, threshold: 100),
        .init(id: "streak_365", title: "Lunar Year",      detail: "365-day streak",  lockedIcon: "moon",            unlockedIcon: "sparkles",               category: .streak, threshold: 365),
    ]

    static let focusAchievements: [StillAchievement] = [
        .init(id: "focus_1h",   title: "Starlight",       detail: "1 hour focused",    lockedIcon: "star",     unlockedIcon: "star.fill",             category: .focusHours, threshold: 1),
        .init(id: "focus_5h",   title: "Constellation",   detail: "5 hours focused",   lockedIcon: "star",     unlockedIcon: "sparkle",               category: .focusHours, threshold: 5),
        .init(id: "focus_10h",  title: "Nebula",          detail: "10 hours focused",  lockedIcon: "star",     unlockedIcon: "cloud.moon.fill",       category: .focusHours, threshold: 10),
        .init(id: "focus_24h",  title: "Full Day",        detail: "24 hours focused",  lockedIcon: "star",     unlockedIcon: "sun.and.horizon.fill",  category: .focusHours, threshold: 24),
        .init(id: "focus_50h",  title: "Aurora",          detail: "50 hours focused",  lockedIcon: "star",     unlockedIcon: "moon.haze.fill",        category: .focusHours, threshold: 50),
        .init(id: "focus_100h", title: "Galaxy",          detail: "100 hours focused", lockedIcon: "star",     unlockedIcon: "moon.stars.fill",       category: .focusHours, threshold: 100),
        .init(id: "focus_500h", title: "Universe",        detail: "500 hours focused", lockedIcon: "star",     unlockedIcon: "globe.americas.fill",   category: .focusHours, threshold: 500),
    ]
}

// MARK: - Tracker

enum AchievementTracker {
    private static let unlockedKey = "stillUnlockedAchievements"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupId)
    }

    /// IDs of all achievements the user has unlocked.
    static func unlockedIDs() -> Set<String> {
        Set(defaults?.stringArray(forKey: unlockedKey) ?? [])
    }

    static func isUnlocked(_ id: String) -> Bool {
        unlockedIDs().contains(id)
    }

    /// Check current stats and unlock any newly-earned achievements.
    /// Returns the list of *newly* unlocked achievement IDs (for animation triggers).
    @discardableResult
    static func evaluateAndUnlock() -> [String] {
        let streak = StreakTracker.currentStreak()
        let totalHours = Int(AppGroupStore.shared.totalFocusSeconds / 3600)
        var unlocked = unlockedIDs()
        var newlyUnlocked: [String] = []

        for a in AchievementCatalog.all {
            guard !unlocked.contains(a.id) else { continue }
            let met: Bool
            switch a.category {
            case .streak:     met = streak >= a.threshold
            case .focusHours: met = totalHours >= a.threshold
            }
            if met {
                unlocked.insert(a.id)
                newlyUnlocked.append(a.id)
            }
        }

        if !newlyUnlocked.isEmpty {
            defaults?.set(Array(unlocked), forKey: unlockedKey)
        }

        return newlyUnlocked
    }

    static func unlockedCount() -> Int {
        unlockedIDs().count
    }

    static func totalCount() -> Int {
        AchievementCatalog.all.count
    }
}

extension StillAchievement {
    /// Short copy for the collectible detail sheet (earned vs. how to unlock).
    func collectibleExplanation(isUnlocked unlocked: Bool) -> String {
        if id == AchievementCatalog.unknownMystery.id {
            return "Every locked collectible looks like this until you earn it."
        }
        if unlocked {
            switch category {
            case .streak:
                return "You earned this by reaching a \(threshold)-day streak."
            case .focusHours:
                let noun = threshold == 1 ? "hour" : "hours"
                return "You earned this after logging \(threshold) \(noun) of focus time."
            }
        } else {
            switch category {
            case .streak:
                return "Reach a \(threshold)-day streak to unlock this collectible."
            case .focusHours:
                let noun = threshold == 1 ? "hour" : "hours"
                return "Log \(threshold) total \(noun) of focus time to unlock this collectible."
            }
        }
    }
}
