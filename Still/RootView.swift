import FamilyControls
import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var session: FocusSessionController
    @EnvironmentObject private var alarmStore: AlarmStore
    @EnvironmentObject private var alarmCoordinator: AlarmRingingCoordinator

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .fullScreenCover(item: Binding(
            get: { alarmCoordinator.activeRinging },
            set: { alarmCoordinator.activeRinging = $0 }
        )) { context in
            AlarmRingingView(context: context, coordinator: alarmCoordinator)
                .interactiveDismissDisabled(true)
        }
        .animation(.easeOut(duration: Tokens.Motion.standard), value: hasCompletedOnboarding)
        .onChange(of: hasCompletedOnboarding) { done in
            guard done else { return }
            Task { await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms) }
        }
        .task {
            session.syncFromStore()
            session.completeNaturallyIfNeeded()
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            session.completeNaturallyIfNeeded()
            session.syncFromStore()
        }
    }
}
