# Still (AllinOneApp_iOS)

iOS app repo for **Still**, synced with [Xcode Cloud](https://developer.apple.com/xcode-cloud/) for CI and TestFlight.

Minimal focus + alarm app: choose apps, categories, and sites to shield during a timed session using Apple’s Screen Time APIs, plus alarms.

## Open in Xcode

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you regenerate the project: `brew install xcodegen`.
2. From this folder, run `xcodegen generate` whenever you change `project.yml`.
3. Open **`Still.xcodeproj`**.

## Xcode Cloud and TestFlight

1. In **App Store Connect**, create the app record (bundle ID `com.allinoneapp.still` or your chosen ID).
2. In **Xcode** → **Product** → **Xcode Cloud** → **Create Workflow** for this project (or set it up in the Report navigator).
3. Choose the **GitHub** repo [TheBarmaanCoder/AllinOneApp_iOS](https://github.com/TheBarmaanCoder/AllinOneApp_iOS) and branch **`main`**.
4. Use the shared scheme **`Still`** for the iOS app target. Ensure **StillMonitor** and **StillShield** are embedded in the app (already configured in the project).
5. Add **App Store Connect API** or **GitHub** integration when prompted so Xcode Cloud can clone and sign builds.
6. After a successful archive, enable **TestFlight** internal testing, then external testing when ready.

`Still.xcodeproj` is committed, so Cloud does not need to run XcodeGen unless you remove the project from git.

## Signing and capabilities

- Select your **Team** on the **Still**, **StillMonitor**, and **StillShield** targets.
- Ensure the **App Group** `group.com.allinoneapp.still` exists for your App ID and matches the entitlements files.
- **Family Controls** requires Apple’s entitlement for distribution beyond personal devices. Request it in the Apple Developer account, then enable the capability on all three targets.
- **AlarmKit** (iOS 26+): follow current Apple guidance for any required entitlements or capabilities for App Store distribution.

## Notes

- **Simulator**: Screen Time / shielding behavior is limited; use a **physical device** for realistic testing.
- Replace the placeholder **App Icon** in `Still/Assets.xcassets` before shipping.
