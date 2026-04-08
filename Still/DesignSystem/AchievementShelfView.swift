import SwiftUI

/// Horizontal scrollable shelf of moon-themed achievement collectibles.
struct AchievementShelfView: View {
    let isPro: Bool
    @State private var unlockedIDs: Set<String> = AchievementTracker.unlockedIDs()
    @State private var selectedAchievement: StillAchievement?

    private var achievements: [StillAchievement] {
        AchievementCatalog.all.sorted { a, b in
            let aUnlocked = unlockedIDs.contains(a.id)
            let bUnlocked = unlockedIDs.contains(b.id)
            if aUnlocked != bUnlocked { return aUnlocked }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            HStack {
                Text("Collectibles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                Spacer()
                Text("\(unlockedIDs.count)/\(achievements.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(achievements) { achievement in
                        collectibleCell(achievement)
                    }
                }
                .padding(.vertical, 4)
            }

            if let selected = selectedAchievement {
                achievementDetail(selected)
            }
        }
        .onAppear { unlockedIDs = AchievementTracker.unlockedIDs() }
    }

    // MARK: - Cell

    private func collectibleCell(_ a: StillAchievement) -> some View {
        let unlocked = unlockedIDs.contains(a.id)
        let isSelected = selectedAchievement?.id == a.id

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedAchievement = selectedAchievement?.id == a.id ? nil : a
            }
            StillHaptics.selectionChanged()
        } label: {
            ZStack {
                if unlocked {
                    Circle()
                        .fill(accentGradient)
                        .frame(width: 52, height: 52)
                        .shadow(color: shadowColor.opacity(0.3), radius: 6, x: 0, y: 3)
                } else {
                    Circle()
                        .fill(lockedFill)
                        .frame(width: 52, height: 52)
                }

                Image(systemName: unlocked ? a.unlockedIcon : a.lockedIcon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(unlocked ? iconColor : Tokens.ColorName.textTertiary.opacity(0.4))
                    .symbolRenderingMode(.hierarchical)
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? Tokens.ColorName.accent : .clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func achievementDetail(_ a: StillAchievement) -> some View {
        let unlocked = unlockedIDs.contains(a.id)
        return HStack(spacing: Tokens.Spacing.md) {
            Image(systemName: unlocked ? a.unlockedIcon : a.lockedIcon)
                .font(.title3)
                .foregroundStyle(unlocked ? Tokens.ColorName.accent : Tokens.ColorName.textTertiary)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(a.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                Text(unlocked ? "Unlocked" : a.detail)
                    .font(.caption)
                    .foregroundStyle(unlocked ? .green : Tokens.ColorName.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 4)
        .transition(.opacity)
    }

    // MARK: - Style helpers

    private var accentGradient: LinearGradient {
        let theme = StillTheme.current
        if theme == .dark {
            return LinearGradient(
                colors: [Color(white: 0.22), Color(white: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(white: 0.92), Color(white: 0.84)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var lockedFill: Color {
        Tokens.ColorName.surfaceMuted.opacity(0.6)
    }

    private var iconColor: Color {
        StillTheme.current == .dark ? .white : .black
    }

    private var shadowColor: Color {
        StillTheme.current == .dark ? .white : .black
    }
}
