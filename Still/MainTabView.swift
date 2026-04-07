import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @AppStorage("stillTheme") private var themeRaw: String = StillTheme.light.rawValue
    @State private var tab: Tab = .focus

    private enum Tab: Hashable {
        case focus
        case alarm
        case settings
    }

    var body: some View {
        TabView(selection: $tab) {
            FocusHomeView()
                .id("focus-\(themeRaw)")
                .tabItem { Label("Focus", systemImage: "moon.stars") }
                .tag(Tab.focus)

            AlarmTabView(alarmStore: alarmStore)
                .id("alarm-\(themeRaw)")
                .tabItem { Label("Alarm", systemImage: "alarm") }
                .tag(Tab.alarm)

            SettingsViewScreen()
                .id("settings-\(themeRaw)")
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Tokens.ColorName.accent)
        .onChange(of: tab) { _ in
            StillHaptics.selectionChanged()
        }
    }
}
