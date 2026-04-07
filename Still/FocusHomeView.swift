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
    @State private var now = Date()

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
                    tallySection

                    FocusStatusHeader(isActive: session.isSessionActive, endsAt: session.sessionEndsAt)

                    if session.isSessionActive {
                        focusTimerCard
                    } else {
                        DurationBar(
                            preset: $durationPreset,
                            otherHours: $otherHours,
                            otherMinutes: $otherMinutes,
                            showOtherSheet: $showOtherSheet
                        )

                        whatToSetAsideCard

                        if let startError {
                            Text(startError)
                                .font(.footnote)
                                .foregroundStyle(Tokens.ColorName.dangerMuted)
                        }

                        PrimaryButton(title: "Begin focus") {
                            startSession()
                        }
                    }

                    groupsSection

                    stillModeSection
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
            if isShowing {
                StillHaptics.lightImpact()
            }
        }
        .sheet(isPresented: $showBreakFlow) {
            BreakFocusFlowView {
                showBreakFlow = false
            }
            .environmentObject(session)
        }
        .sheet(isPresented: $showOtherSheet) {
            OtherDurationSheet(
                hours: $otherHours,
                minutes: $otherMinutes,
                onCancel: {
                    showOtherSheet = false
                },
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
        .onChange(of: showStillModePicker) { showing in
            if !showing {
                stillMode.saveSelection(stillModeSelection)
            }
        }
        .onAppear {
            refreshTally()
            reloadGroups()
            stillModeSelection = stillMode.loadSelection()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
            refreshTally()
        }
    }

    private var tallySection: some View {
        CalmCard {
            StatBlock(
                title: "Total focus time",
                value: formattedDuration(totalSeconds),
                footnote: completedSessions == 0
                    ? "Completed sessions add here automatically."
                    : "\(completedSessions) completed session\(completedSessions == 1 ? "" : "s")"
            )
        }
    }

    private var whatToSetAsideCard: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("What to set aside")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                    .padding(.bottom, Tokens.Spacing.xs)

                Text("Pick manually, use a saved group, or combine both.")
                    .font(.footnote)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
                    .padding(.bottom, Tokens.Spacing.md)

                manualPickRow

                if !groups.isEmpty {
                    ForEach(groups) { group in
                        Divider().background(Tokens.ColorName.separator)
                        groupPickRow(group)
                    }
                }
            }
        }
    }

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
            if selected {
                selectedGroupIDs.remove(group.id)
            } else {
                selectedGroupIDs.insert(group.id)
            }
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

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            Text("Groups")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textPrimary)
            Text("Save sets of apps and sites to reuse from the card above.")
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorName.textSecondary)

            if session.isSessionActive {
                Text("End this session to edit groups.")
                    .font(.footnote)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            } else if groups.isEmpty {
                EmptyState(
                    title: "No groups yet",
                    message: "Create a group to show it as an option above.",
                    actionTitle: "New group"
                ) {
                    isCreatingGroup = true
                }
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
                .padding(.horizontal, Tokens.Spacing.lg)
                .padding(.vertical, Tokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                        .fill(Tokens.ColorName.backgroundSecondary)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
                )

                PrimaryButton(title: "New group") {
                    isCreatingGroup = true
                }
                .disabled(session.isSessionActive)
                .opacity(session.isSessionActive ? 0.45 : 1)
            }
        }
    }

    // MARK: - Focus Timer Card

    private var focusTimerCard: some View {
        CalmCard {
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
    }

    private var focusElapsedText: String {
        guard let start = AppGroupStore.shared.sessionStart else { return "0m" }
        let elapsed = max(0, now.timeIntervalSince(start))
        return formattedDuration(elapsed)
    }

    private var focusRemainingText: String {
        guard let end = session.sessionEndsAt else { return "0m" }
        let remaining = max(0, end.timeIntervalSince(now))
        return formattedDuration(remaining)
    }

    private func focusProgress(endDate: Date) -> Double {
        guard session.plannedDuration > 0 else { return 0 }
        let elapsed = max(0, now.timeIntervalSince(
            AppGroupStore.shared.sessionStart ?? now
        ))
        return min(1, elapsed / session.plannedDuration)
    }

    // MARK: - Still Mode

    private var stillModeSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            HStack {
                Text("Still Mode")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                if !store.isProUnlocked {
                    proBadge
                }
            }
            Text("Scan your QR code with the iPhone camera to instantly block apps. Scan again and type a sentence to exit.")
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorName.textSecondary)

            CalmCard {
                VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
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
                            if store.isProUnlocked {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Tokens.ColorName.textTertiary)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Tokens.ColorName.textTertiary)
                            }
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
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallSheet()
        }
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.orange))
    }

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

    private func reloadGroups() {
        groups = FocusGroupStore.load()
    }

    private func refreshTally() {
        totalSeconds = AppGroupStore.shared.totalFocusSeconds
        completedSessions = AppGroupStore.shared.completedSessions
    }

    private func formattedDuration(_ t: TimeInterval) -> String {
        let hours = Int(t) / 3600
        let minutes = (Int(t) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
