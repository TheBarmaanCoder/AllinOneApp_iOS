import SwiftUI

/// Horizontal scrollable shelf of moon-themed achievement collectibles.
///
/// This view builds its own card background rather than using `CalmCard`,
/// because the scroll strip must span the full card width while the header
/// text stays inset. Using CalmCard and then fighting its padding with
/// negative insets caused the clipping bugs.
struct AchievementShelfView: View {
    let isPro: Bool
    /// External height to match (e.g. the stats row). Orb size adapts.
    var matchHeight: CGFloat?

    @State private var unlockedIDs: Set<String> = AchievementTracker.unlockedIDs()
    @State private var detailAchievement: StillAchievement?

    // MARK: - Derived layout constants

    /// Orb diameter — fills available vertical space minus header + breathing room.
    private var orbSize: CGFloat {
        guard let h = matchHeight, h > 60 else { return 44 }
        let headerBlock: CGFloat = 20
        let verticalPad = cardPadTop + cardPadBottom
        let available = h - headerBlock - verticalPad
        return max(28, min(52, available))
    }

    private let cardPadH: CGFloat = Tokens.Spacing.xl        // 24 – matches CalmCard
    private let cardPadTop: CGFloat = Tokens.Spacing.lg       // 20
    private let cardPadBottom: CGFloat = Tokens.Spacing.lg    // 20

    /// Wide spacing — roughly 3 orbs visible at a time on a standard-width phone.
    private let orbSpacing: CGFloat = 28

    // MARK: - Data

    private var achievements: [StillAchievement] {
        let sorted = AchievementCatalog.all.sorted { a, b in
            let aU = unlockedIDs.contains(a.id)
            let bU = unlockedIDs.contains(b.id)
            if aU != bU { return aU }
            return false
        }
        return sorted + [AchievementCatalog.unknownMystery]
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header — inset to match other CalmCards
            HStack(alignment: .firstTextBaseline) {
                Text("Collectibles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                Spacer()
                Text("\(unlockedIDs.count)/\(AchievementCatalog.all.count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }
            .padding(.horizontal, cardPadH)

            // Scroll strip — full card width; orbs are inset via content padding
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: orbSpacing) {
                    ForEach(achievements) { achievement in
                        cellButton(achievement)
                    }
                }
                .padding(.horizontal, cardPadH)
            }
        }
        .padding(.top, cardPadTop)
        .padding(.bottom, cardPadBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Card background (same look as CalmCard) — no clipShape so orb shadows aren't cut off
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                .fill(Tokens.ColorName.backgroundSecondary)
                .shadow(
                    color: StillTheme.current == .dark
                        ? Color.white.opacity(0.04)
                        : Color.black.opacity(0.06),
                    radius: 10, x: 0, y: 3
                )
        )
        .onAppear { unlockedIDs = AchievementTracker.unlockedIDs() }
        .sheet(item: $detailAchievement) { achievement in
            CollectibleDetailSheet(
                achievement: achievement,
                unlocked: isAchievementUnlocked(achievement)
            )
        }
    }

    // MARK: - Helpers

    private func cellButton(_ a: StillAchievement) -> some View {
        let unlocked = isAchievementUnlocked(a)
        return Button {
            detailAchievement = a
            StillHaptics.selectionChanged()
        } label: {
            CollectibleOrbCluster(achievement: a, unlocked: unlocked, size: orbSize)
        }
        .buttonStyle(.plain)
    }

    private func isAchievementUnlocked(_ a: StillAchievement) -> Bool {
        if a.id == AchievementCatalog.unknownMystery.id { return false }
        return unlockedIDs.contains(a.id)
    }
}

// MARK: - Detail sheet (unchanged)

private struct CollectibleDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let achievement: StillAchievement
    let unlocked: Bool

    private let heroOrbSize: CGFloat = 140

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                CollectibleOrbCluster(achievement: achievement, unlocked: unlocked, size: heroOrbSize)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text(statusHeadline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)

                    Text(achievement.collectibleExplanation(isUnlocked: unlocked))
                        .font(.body)
                        .foregroundStyle(Tokens.ColorName.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .navigationTitle(achievement.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var statusHeadline: String {
        if achievement.id == AchievementCatalog.unknownMystery.id { return "Legend" }
        return unlocked ? "Unlocked" : "Locked"
    }

    private var statusColor: Color {
        if achievement.id == AchievementCatalog.unknownMystery.id {
            return Tokens.ColorName.textTertiary
        }
        return unlocked ? .green : Tokens.ColorName.textTertiary
    }
}
