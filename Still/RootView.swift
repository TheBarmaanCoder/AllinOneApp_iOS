import FamilyControls
import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var cloudRefreshEpoch = 0
    @EnvironmentObject private var session: FocusSessionController
    @EnvironmentObject private var alarmStore: AlarmStore
    @EnvironmentObject private var alarmCoordinator: AlarmRingingCoordinator
    @EnvironmentObject private var stillMode: StillModeController
    @EnvironmentObject private var store: StoreManager

    private var onboardingComplete: Bool {
        _ = cloudRefreshEpoch
        return UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    var body: some View {
        Group {
            if onboardingComplete {
                MainTabView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .fullScreenCover(item: Binding(
            get: { alarmCoordinator.activeRinging },
            set: { _ in }
        )) { context in
            AlarmRingingView(context: context, coordinator: alarmCoordinator)
                .interactiveDismissDisabled(true)
        }
        .fullScreenCover(isPresented: Binding(
            get: {
                stillMode.isActive
                    || stillMode.pendingExit
                    || (session.isCheatActive && session.cheatSourceMode == "still")
            },
            set: { _ in }
        )) {
            StillModeActiveOverlay(controller: stillMode)
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $stillMode.showProPaywall) {
            ProPaywallSheet()
        }
        .animation(.easeOut(duration: Tokens.Motion.standard), value: hasCompletedOnboarding)
        .onReceive(NotificationCenter.default.publisher(for: .stillCloudPreferencesMerged)) { _ in
            cloudRefreshEpoch += 1
            stillMode.syncFromStore()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stillModeStoreNeedsSync)) { _ in
            stillMode.syncFromStore()
        }
        .onChange(of: hasCompletedOnboarding) { done in
            guard done else { return }
            CloudPreferencesSync.schedulePushDebounced()
            Task { await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms) }
        }
        .task {
            session.syncFromStore()
            stillMode.syncFromStore()
            session.completeNaturallyIfNeeded()
        }
        .onChange(of: session.isCheatActive) { _ in
            stillMode.syncFromStore()
        }
        .onChange(of: session.cheatSourceMode) { _ in
            stillMode.syncFromStore()
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            session.completeNaturallyIfNeeded()
            session.syncFromStore()
            stillMode.syncFromStore()
        }
    }
}
