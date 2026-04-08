import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @AppStorage("stillTheme") private var themeRaw: String = StillTheme.light.rawValue
    @State private var cloudTabEpoch = 0
    @State private var tab: Tab = .focus

    private enum Tab: Hashable {
        case focus
        case alarm
        case settings
    }

    var body: some View {
        TabView(selection: $tab) {
            FocusHomeView()
                .id("focus-\(themeRaw)-\(cloudTabEpoch)")
                .tabItem { Label("Focus", systemImage: "moon.stars") }
                .tag(Tab.focus)

            AlarmTabView(alarmStore: alarmStore)
                .id("alarm-\(themeRaw)-\(cloudTabEpoch)")
                .tabItem { Label("Alarm", systemImage: "alarm") }
                .tag(Tab.alarm)

            SettingsViewScreen()
                .id("settings-\(themeRaw)-\(cloudTabEpoch)")
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Tokens.ColorName.accent)
        .onReceive(NotificationCenter.default.publisher(for: .stillCloudPreferencesMerged)) { _ in
            cloudTabEpoch += 1
        }
        .onChange(of: tab) { _ in
            StillHaptics.selectionChanged()
        }
    }
}
