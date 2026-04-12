import SwiftUI

@main
struct StillApp: App {
    @UIApplicationDelegateAdaptor(StillAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = FocusSessionController()
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var alarmCoordinator = AlarmRingingCoordinator()
    @StateObject private var stillMode = StillModeController()
    @StateObject private var store = StoreManager()
    @State private var cloudPaintEpoch = 0

    private var theme: StillTheme {
        _ = cloudPaintEpoch
        let raw = UserDefaults.standard.string(forKey: "stillTheme") ?? StillTheme.light.rawValue
        return StillTheme(rawValue: raw) ?? .light
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(alarmStore)
                .environmentObject(alarmCoordinator)
                .environmentObject(stillMode)
                .environmentObject(store)
                .tint(Tokens.ColorName.accent)
                .preferredColorScheme(theme.colorScheme)
                .task {
                    await CloudPreferencesSync.pullAndMergeIfNeeded()
                    await MainActor.run {
                        alarmStore.load()
                    }
                    await store.refreshStatus()
                    appDelegate.alarmCoordinator = alarmCoordinator
                    alarmCoordinator.configure(store: alarmStore)
                    await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms)
                    if #available(iOS 26.0, *) {
                        await alarmCoordinator.observeAlarmKitUpdates()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .stillCloudPreferencesMerged)) { _ in
                    cloudPaintEpoch += 1
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    session.syncFromStore()
                    stillMode.syncFromStore()
                    // App group writes from the shield extension can lag one runloop; resync shortly after.
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        session.syncFromStore()
                        stillMode.syncFromStore()
                    }
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task {
                            await CloudPreferencesSync.pullAndMergeIfNeeded()
                            await MainActor.run {
                                alarmStore.load()
                            }
                            await store.refreshStatus()
                            await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms)
                        }
                        alarmCoordinator.restorePendingAndForegroundAudioIfNeeded()
                        session.syncFromStore()
                        stillMode.syncFromStore()
                        CloudPreferencesSync.schedulePushDebounced()
                    } else if phase == .background {
                        Task {
                            await alarmCoordinator.rescheduleNagsIfChallengePending()
                            await CloudPreferencesSync.pushSnapshot()
                        }
                    }
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == AlarmConstants.qrURLScheme,
              url.host == "dismiss",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              AlarmQRTokenStore.matches(token)
        else { return }

        Task {
            let handled = await alarmCoordinator.handleOpenURL(url)
            if handled { return }

            await MainActor.run {
                session.syncFromStore()
                if !store.isProUnlocked {
                    stillMode.showProPaywall = true
                    return
                }

                if stillMode.isActive {
                    stillMode.requestExit()
                } else {
                    guard !session.isSessionActive else { return }
                    stillMode.activate()
                }
            }
        }
    }
}
