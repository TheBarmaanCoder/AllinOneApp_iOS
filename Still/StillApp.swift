import SwiftUI

@main
struct StillApp: App {
    @UIApplicationDelegateAdaptor(StillAppDelegate.self) private var appDelegate
    @StateObject private var session = FocusSessionController()
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var alarmCoordinator = AlarmRingingCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(alarmStore)
                .environmentObject(alarmCoordinator)
                .tint(Tokens.ColorName.accent)
                .preferredColorScheme(.light)
                .task {
                    appDelegate.alarmCoordinator = alarmCoordinator
                    alarmCoordinator.configure(store: alarmStore)
                    await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms)
                    if #available(iOS 26.0, *) {
                        await alarmCoordinator.observeAlarmKitUpdates()
                    }
                }
                .onOpenURL { url in
                    Task {
                        _ = await alarmCoordinator.handleOpenURL(url)
                    }
                }
        }
    }
}
