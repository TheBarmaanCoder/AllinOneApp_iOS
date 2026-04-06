# Still

Minimal focus app for iOS: choose apps, categories, and sites to shield during a timed session using Apple’s Screen Time APIs.

## Open in Xcode

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you regenerate the project: `brew install xcodegen`.
2. From this folder, run `xcodegen generate` whenever you change `project.yml`.
3. Open **`Still.xcodeproj`**.

## Signing and capabilities

- Select your **Team** on the **Still**, **StillMonitor**, and **StillShield** targets.
- Ensure the **App Group** `group.com.allinoneapp.still` exists for your App ID and matches the entitlements files.
- **Family Controls** requires Apple’s entitlement for distribution beyond personal devices. Request it in the Apple Developer account, then enable the capability on all three targets.

## Notes

- **Simulator**: Screen Time / shielding behavior is limited; use a **physical device** for realistic testing.
- Replace the placeholder **App Icon** in `Still/Assets.xcassets` before shipping.
