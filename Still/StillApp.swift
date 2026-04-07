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
    @AppStorage("stillTheme") private var themeRaw: String = StillTheme.light.rawValue

    private var theme: StillTheme {
        StillTheme(rawValue: themeRaw) ?? .light
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
                    appDelegate.alarmCoordinator = alarmCoordinator
                    alarmCoordinator.configure(store: alarmStore)
                    await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms)
                    await store.refreshStatus()
                    if #available(iOS 26.0, *) {
                        await alarmCoordinator.observeAlarmKitUpdates()
                    }
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        alarmCoordinator.restorePendingAndForegroundAudioIfNeeded()
                        stillMode.syncFromStore()
                    } else if phase == .background {
                        Task {
                            await alarmCoordinator.rescheduleNagsIfChallengePending()
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
                if !store.isProUnlocked {
                    stillMode.showProPaywall = true
                    return
                }

                if stillMode.isActive {
                    stillMode.requestExit()
                } else {
                    stillMode.activate()
                }
            }
        }
    }
}
