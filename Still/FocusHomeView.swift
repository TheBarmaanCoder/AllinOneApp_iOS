import FamilyControls
import SwiftUI

struct FocusHomeView: View {
    @EnvironmentObject private var session: FocusSessionController
    @EnvironmentObject private var stillMode: StillModeController
    @EnvironmentObject private var store: StoreManager

    @State private var extraSelection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var showStillModePicker = false
    @State private var showPaywall = false
    @State private var stillModeSelection = FamilyActivitySelection()
    @State private var durationPreset: DurationBarPreset = .thirty
    @State private var otherHours = 0
    @State private var otherMinutes = 30
    @State private var showOtherSheet = false
    @State private var showBreakFlow = false
    @State private var startError: String?
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var groups: [StoredFocusGroup] = FocusGroupStore.load()
    @State private var editing: StoredFocusGroup?
    @State private var isCreatingGroup = false
    @State private var totalSeconds: TimeInterval = AppGroupStore.shared.totalFocusSeconds
    @State private var completedSessions: Int = AppGroupStore.shared.completedSessions
    @State private var todaySeconds: TimeInterval = DailyFocusLog.todaySeconds()
    @State private var currentStreak: Int = StreakTracker.currentStreak()
    @State private var scheduledBlocks: [ScheduledBlock] = ScheduledBlockStore.load()
    @State private var editingScheduledBlock: ScheduledBlock?
    @State private var isCreatingScheduledBlock = false
    @State private var now = Date()
    @State private var screenTimeStatus: AuthorizationStatus = FocusAuthorization.authorizationStatus()
    @State private var showStreakInfo = false
    @State private var showCheatGuideBanner = false

    private var durationMinutes: Int {
        switch durationPreset {
        case .thirty: return 30
        case .oneHour: return 60
        case .ninety: return 90
        case .twoHours: return 120
        case .other:
            return min(23 * 60 + 59, max(1, otherHours * 60 + otherMinutes))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {

                    // ── Page header ──
                    Text("Focus")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Tokens.ColorName.textPrimary)

                    if session.isCheatActive {
                        cheatGlobalTimerBanner
                    }

                    if showCheatGuideBanner {
                        cheatGuideBanner
                    }

                    // ── Stats + Achievements ──
                    statsRow
                    achievementSection

                    // ── Screen Time re-request (if needed) ──
                    if screenTimeStatus != .approved {
                        screenTimeCard
                    }

                    // ── Focus Session group ──
                    focusSessionGroup

                    // ── Scheduled Blocks group ──
                    scheduledBlocksGroup

                    // ── Still Mode group ──
                    stillModeGroup
                }
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.vertical, Tokens.Spacing.screenVertical)
            }
            .background(Tokens.ColorName.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $extraSelection)
        .familyActivityPicker(isPresented: $showStillModePicker, selection: $stillModeSelection)
        .onChange(of: showPicker) { isShowing in
            if isShowing { StillHaptics.lightImpact() }
        }
        .sheet(isPresented: $showBreakFlow) {
            BreakFocusFlowView { showBreakFlow = false }
                .environmentObject(session)
        }
        .sheet(isPresented: $showOtherSheet) {
            OtherDurationSheet(
                hours: $otherHours,
                minutes: $otherMinutes,
                onCancel: { showOtherSheet = false },
                onDone: {
                    durationPreset = .other
                    showOtherSheet = false
                }
            )
        }
        .sheet(isPresented: $isCreatingGroup) {
            GroupEditorSheet(mode: .create) {
                reloadGroups()
                isCreatingGroup = false
            }
        }
        .sheet(item: $editing) { group in
            GroupEditorSheet(mode: .edit(group)) {
                reloadGroups()
                editing = nil
            }
        }
        .sheet(isPresented: $isCreatingScheduledBlock) {
            ScheduledBlockEditorSheet(mode: .create) { reloadScheduledBlocks() }
        }
        .sheet(item: $editingScheduledBlock) { block in
            ScheduledBlockEditorSheet(mode: .edit(block)) { reloadScheduledBlocks() }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallSheet()
        }
        .onChange(of: showStillModePicker) { showing in
            if !showing { stillMode.saveSelection(stillModeSelection) }
        }
        .onAppear {
            session.syncFromStore()
            refreshTally()
            reloadGroups()
            reloadScheduledBlocks()
            stillModeSelection = stillMode.loadSelection()
            screenTimeStatus = FocusAuthorization.authorizationStatus()
        }
        .onChange(of: session.isCheatActive) { isActive in
            guard isActive else { return }
            Task {
                try? await Task.sleep(nanoseconds: 450_000_000)
                await MainActor.run {
                    let defaults = UserDefaults(suiteName: AppConstants.appGroupId)
                    guard defaults?.bool(forKey: "stillCheatShowWarning") == true else { return }
                    defaults?.set(false, forKey: "stillCheatShowWarning")
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        showCheatGuideBanner = true
                    }
                }
            }
        }
        .task(id: showCheatGuideBanner) {
            guard showCheatGuideBanner else { return }
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    showCheatGuideBanner = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stillCloudPreferencesMerged)) { _ in
            stillModeSelection = stillMode.loadSelection()
            refreshTally()
            reloadGroups()
            reloadScheduledBlocks()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
            refreshTally()
        }
    }

    // ────────────────────────────────────────────
    // MARK: - Stats Row
    // ────────────────────────────────────────────

    private var statsRow: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            miniStatCard(title: "Today", value: formattedDuration(todaySeconds), icon: "sun.max.fill")
            miniStatCard(title: "Total", value: formattedDuration(totalSeconds), icon: "clock.fill")
            streakCard
        }
    }

    private func miniStatCard(title: String, value: String, icon: String) -> some View {
        CalmCard {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
                Text(value)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }
        }
    }

    private var streakCard: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.caption)
                    Button {
                        showStreakInfo = true
                        StillHaptics.lightImpact()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(Tokens.ColorName.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                Text("\(currentStreak)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(currentStreak > 0 ? Color.orange : Tokens.ColorName.textPrimary)
                    .contentTransition(.numericText())
                Text(currentStreak == 1 ? "day" : "days")
                    .font(.caption2)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }
        }
        .alert("How streaks work", isPresented: $showStreakInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A day counts toward your streak only after 30+ minutes of total focus time that day.")
        }
    }

    private var achievementSection: some View {
        CalmCard {
            AchievementShelfView(isPro: store.isProUnlocked)
        }
    }

    // ────────────────────────────────────────────
    // MARK: - Screen Time re-request
    // ────────────────────────────────────────────

    private var screenTimeCard: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                Label("Screen Time access needed", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Still needs Screen Time access to block apps during focus. If another app reset your settings, re-allow it here.")
                    .font(.caption)
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton(title: "Allow Screen Time") {
                    Task {
                        do {
                            try await FocusAuthorization.requestAuthorization()
                            StillHaptics.selectionChanged()
                        } catch {
                            StillHaptics.warning()
                        }
                        screenTimeStatus = FocusAuthorization.authorizationStatus()
                    }
                }
            }
        }
    }

    // ────────────────────────────────────────────
    // MARK: - Focus Session Group
    // ────────────────────────────────────────────

    private var focusSessionGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "Focus Session", icon: "moon.fill")

            VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                if session.isCheatActive && session.cheatSourceMode == "focus" {
                    cheatCountdownContent(reengageTitle: "Restore focus session")
                } else {
                    if session.isSessionActive {
                        focusTimerCard
                    } else {
                        DurationBar(
                            preset: $durationPreset,
                            otherHours: $otherHours,
                            otherMinutes: $otherMinutes,
                            showOtherSheet: $showOtherSheet
                        )

                        whatToSetAsideContent

                        if let startError {
                            Text(startError)
                                .font(.footnote)
                                .foregroundStyle(Tokens.ColorName.dangerMuted)
                        }

                        PrimaryButton(title: "Begin focus") {
                            startSession()
                        }
                    }

                    sectionDivider

                    groupsContent
                }
            }
            .padding(Tokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                    .fill(Tokens.ColorName.backgroundSecondary)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
            )
        }
    }

    // MARK: What to set aside (inside Focus Session)

    private var whatToSetAsideContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What to set aside")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textSecondary)
                .padding(.bottom, Tokens.Spacing.xs)

            manualPickRow

            if !groups.isEmpty {
                ForEach(groups) { group in
                    Divider().background(Tokens.ColorName.separator)
                    groupPickRow(group)
                }
            }
        }
    }

    // MARK: Groups (inside Focus Session)

    private var groupsContent: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            Text("Groups")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textSecondary)

            if session.isSessionActive {
                Text("End this session to edit groups.")
                    .font(.footnote)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            } else if groups.isEmpty {
                Text("No groups yet. Create one to reuse app sets.")
                    .font(.footnote)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(groups) { g in
                        Button {
                            StillHaptics.lightImpact()
                            editing = g
                        } label: {
                            ListRow(title: g.name, subtitle: "Edit", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        if g.id != groups.last?.id {
                            Divider().background(Tokens.ColorName.separator)
                        }
                    }
                }
            }

            if !session.isSessionActive {
                Button {
                    StillHaptics.lightImpact()
                    isCreatingGroup = true
                } label: {
                    HStack(spacing: Tokens.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                        Text("New group")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(Tokens.ColorName.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ────────────────────────────────────────────
    // MARK: - Scheduled Blocks Group
    // ────────────────────────────────────────────

    private var scheduledBlocksGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader(title: "Scheduled Blocks", icon: "calendar.badge.clock")
                if !store.isProUnlocked {
                    proBadge
                }
            }

            if store.isProUnlocked {
                VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                    Text("Auto-block apps on a weekly schedule.")
                        .font(.footnote)
                        .foregroundStyle(Tokens.ColorName.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !scheduledBlocks.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(scheduledBlocks) { block in
                                Button {
                                    StillHaptics.lightImpact()
                                    editingScheduledBlock = block
                                } label: {
                                    HStack(alignment: .center, spacing: Tokens.Spacing.md) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(block.name)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(block.enabled ? Tokens.ColorName.textPrimary : Tokens.ColorName.textTertiary)
                                            Text("\(block.weekdayAbbreviations) · \(block.formattedTime)")
                                                .font(.caption)
                                                .foregroundStyle(Tokens.ColorName.textSecondary)
                                        }
                                        Spacer(minLength: 0)
                                        Circle()
                                            .fill(block.enabled ? Color.green : Tokens.ColorName.surfaceMuted)
                                            .frame(width: 8, height: 8)
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Tokens.ColorName.textTertiary)
                                    }
                                    .padding(.vertical, Tokens.Spacing.sm)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if block.id != scheduledBlocks.last?.id {
                                    Divider().background(Tokens.ColorName.separator)
                                }
                            }
                        }
                    }

                    Button {
                        StillHaptics.lightImpact()
                        isCreatingScheduledBlock = true
                    } label: {
                        HStack(spacing: Tokens.Spacing.xs) {
                            Image(systemName: "plus.circle.fill")
                                .font(.body)
                            Text("New scheduled block")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(Tokens.ColorName.accent)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Tokens.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                        .fill(Tokens.ColorName.backgroundSecondary)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
                )
            } else {
                VStack(spacing: Tokens.Spacing.sm) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(Tokens.ColorName.textTertiary)
                    Text("Unlock Still Pro to create auto-blocking schedules")
                        .font(.caption)
                        .foregroundStyle(Tokens.ColorName.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(Tokens.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                        .fill(Tokens.ColorName.backgroundSecondary)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
                )
                .onTapGesture { showPaywall = true }
            }
        }
    }

    // ────────────────────────────────────────────
    // MARK: - Still Mode Group
    // ────────────────────────────────────────────

    private var stillModeGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader(title: "Still Mode", icon: "qrcode.viewfinder")
                if !store.isProUnlocked {
                    proBadge
                }
            }

            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                if session.isCheatActive && session.cheatSourceMode == "still" {
                    cheatCountdownContent(reengageTitle: "Restore Still Mode")
                } else {
                    Text("Scan your QR code with the iPhone camera to instantly block apps. Scan again and type a sentence to exit.")
                        .font(.footnote)
                        .foregroundStyle(Tokens.ColorName.textTertiary)

                    Button {
                        StillHaptics.lightImpact()
                        if store.isProUnlocked {
                            showStillModePicker = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack(alignment: .center, spacing: Tokens.Spacing.md) {
                            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                                Text("Apps to block in Still Mode")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Tokens.ColorName.textPrimary)
                                Text(store.isProUnlocked ? stillModeSelectionSubtitle : "Requires Still Pro")
                                    .font(.caption)
                                    .foregroundStyle(Tokens.ColorName.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: store.isProUnlocked ? "chevron.right" : "lock.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Tokens.ColorName.textTertiary)
                        }
                        .padding(.vertical, Tokens.Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Label("Print your QR from Settings, then scan it with your camera to activate.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Tokens.ColorName.textTertiary)
                }
            }
            .padding(Tokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                    .fill(Tokens.ColorName.backgroundSecondary)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
            )
        }
    }

    private var cheatGlobalTimerBanner: some View {
        HStack(alignment: .center, spacing: Tokens.Spacing.md) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.cheatSourceMode == "still" ? "Still Mode cheat" : "Focus cheat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                Text(formattedCountdown(session.cheatRemainingSeconds))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Tokens.ColorName.textPrimary)
            }
            Spacer(minLength: 0)
            Button {
                session.endCheatAndReblock()
                StillHaptics.success()
            } label: {
                Text("End cheat")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.orange))
            }
            .buttonStyle(.plain)
        }
        .padding(Tokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private var cheatGuideBanner: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.sm) {
            Image(systemName: "hand.tap.fill")
                .font(.title3)
                .foregroundStyle(Tokens.ColorName.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Cheat break active")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                Text("Blocked apps stay open until your cheat time ends or you tap Restore below. Use your cheat budget wisely.")
                    .font(.caption)
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showCheatGuideBanner = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Tokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                .fill(Tokens.ColorName.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
    }

    private func cheatCountdownContent(reengageTitle: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            HStack(spacing: Tokens.Spacing.sm) {
                Image(systemName: "timer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Cheat countdown")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
            }

            Text(formattedCountdown(session.cheatRemainingSeconds))
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())

            Text("Use your remaining cheat time, then re-engage to keep your streak.")
                .font(.caption)
                .foregroundStyle(Tokens.ColorName.textSecondary)

            SecondaryButton(title: reengageTitle) {
                session.endCheatAndReblock()
                StillHaptics.success()
            }
        }
    }

    // ────────────────────────────────────────────
    // MARK: - Shared components
    // ────────────────────────────────────────────

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textTertiary)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textPrimary)
        }
        .padding(.bottom, Tokens.Spacing.sm)
    }

    private var sectionDivider: some View {
        Divider()
            .background(Tokens.ColorName.separator)
            .padding(.vertical, Tokens.Spacing.xs)
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.orange))
    }

    // ────────────────────────────────────────────
    // MARK: - Focus Timer Card
    // ────────────────────────────────────────────

    private var focusTimerCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            HStack(spacing: Tokens.Spacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("In focus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Tokens.ColorName.textTertiary)
                    Text(focusElapsedText)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Tokens.ColorName.textPrimary)
                        .contentTransition(.numericText())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remaining")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Tokens.ColorName.textTertiary)
                    Text(focusRemainingText)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Tokens.ColorName.textSecondary)
                        .contentTransition(.numericText())
                }
            }

            if let end = session.sessionEndsAt {
                ProgressView(value: focusProgress(endDate: end))
                    .tint(Tokens.ColorName.textPrimary)
            }

            SecondaryButton(title: "Break focus…") {
                showBreakFlow = true
            }
        }
    }

    private var focusElapsedText: String {
        guard let start = AppGroupStore.shared.sessionStart else { return "0m" }
        return formattedDuration(max(0, now.timeIntervalSince(start)))
    }

    private var focusRemainingText: String {
        guard let end = session.sessionEndsAt else { return "0m" }
        return formattedDuration(max(0, end.timeIntervalSince(now)))
    }

    private func focusProgress(endDate: Date) -> Double {
        guard session.plannedDuration > 0 else { return 0 }
        let elapsed = max(0, now.timeIntervalSince(AppGroupStore.shared.sessionStart ?? now))
        return min(1, elapsed / session.plannedDuration)
    }

    // ────────────────────────────────────────────
    // MARK: - Picker rows
    // ────────────────────────────────────────────

    private var manualPickRow: some View {
        Button {
            StillHaptics.lightImpact()
            showPicker = true
        } label: {
            HStack(alignment: .center, spacing: Tokens.Spacing.md) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                    Text("Choose apps & sites")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Tokens.ColorName.textPrimary)
                    Text(manualSelectionSubtitle)
                        .font(.caption)
                        .foregroundStyle(Tokens.ColorName.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }
            .padding(.vertical, Tokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var manualSelectionSubtitle: String {
        let n = manualSelectionCount(extraSelection)
        if n == 0 { return "Custom pick" }
        return n == 1 ? "1 item selected" : "\(n) items selected"
    }

    private func groupPickRow(_ group: StoredFocusGroup) -> some View {
        let selected = selectedGroupIDs.contains(group.id)
        return Button {
            StillHaptics.selectionChanged()
            if selected { selectedGroupIDs.remove(group.id) }
            else { selectedGroupIDs.insert(group.id) }
        } label: {
            HStack(alignment: .center, spacing: Tokens.Spacing.md) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Tokens.ColorName.textPrimary : Tokens.ColorName.textTertiary)
                Text(group.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Tokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // ────────────────────────────────────────────
    // MARK: - Helpers
    // ────────────────────────────────────────────

    private var stillModeSelectionSubtitle: String {
        let n = stillModeSelection.applicationTokens.count
            + stillModeSelection.categoryTokens.count
            + stillModeSelection.webDomainTokens.count
        if n == 0 { return "No apps selected" }
        return n == 1 ? "1 item selected" : "\(n) items selected"
    }

    private func manualSelectionCount(_ selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private func reloadGroups() { groups = FocusGroupStore.load() }
    private func reloadScheduledBlocks() { scheduledBlocks = ScheduledBlockStore.load() }

    private func refreshTally() {
        totalSeconds = AppGroupStore.shared.totalFocusSeconds
        completedSessions = AppGroupStore.shared.completedSessions
        todaySeconds = DailyFocusLog.todaySeconds()
        currentStreak = StreakTracker.currentStreak()
    }

    private func formattedDuration(_ t: TimeInterval) -> String {
        let hours = Int(t) / 3600
        let minutes = (Int(t) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formattedCountdown(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startSession() {
        startError = nil
        guard !stillMode.isActive else {
            startError = "Exit Still Mode before starting a focus session."
            StillHaptics.warning()
            return
        }
        let chosenGroups = groups.filter { selectedGroupIDs.contains($0.id) }
        do {
            let merged = try SelectionMerge.mergedSelection(groups: chosenGroups, extra: extraSelection)
            let totalTokens = merged.applicationTokens.count + merged.categoryTokens.count + merged.webDomainTokens.count
            guard totalTokens > 0 else {
                startError = "Choose apps & sites, a group, or both."
                StillHaptics.warning()
                return
            }
            try session.startFocus(durationMinutes: durationMinutes, selection: merged)
            StillHaptics.success()
        } catch {
            startError = "Could not start focus. Try again."
            StillHaptics.warning()
        }
    }
}
