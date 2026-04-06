import AlarmKit
import CoreMotion
import FamilyControls
import SwiftUI
import UIKit

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var familyStatus: AuthorizationStatus = FocusAuthorization.authorizationStatus()
    @State private var motionStatus: CMAuthorizationStatus = MotionStepAuthorization.status()
    @State private var requestingFamily = false
    @State private var requestingMotion = false
    @State private var requestingAlarmKit = false
    @State private var alarmKitAuthorized = false
    @State private var alarmKitDenied = false

    private var screenTimeOK: Bool {
        familyStatus == .approved
    }

    private var motionOK: Bool {
        MotionStepAuthorization.isSatisfiedForApp
    }

    private var canContinue: Bool {
        screenTimeOK && motionOK
    }

    private var familyDenied: Bool {
        familyStatus == .denied
    }

    private var motionDenied: Bool {
        MotionStepAuthorization.isStepCountingAvailable
            && (motionStatus == .denied || motionStatus == .restricted)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxl) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                    Text("Some permissions first")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Tokens.ColorName.textPrimary)
                    introCopy
                }

                permissionCard(
                    title: "Focus",
                    explanation: "Lets Still apply shields only to what you pick. Nothing is sent to us.",
                    isGranted: screenTimeOK,
                    denied: familyDenied,
                    isRequesting: requestingFamily,
                    allowTitle: "Allow Screen Time",
                    onAllow: { Task { await requestScreenTime() } },
                    settingsHint: "Screen Time for Still is off. You can turn it on in Settings → Still."
                )

                permissionCard(
                    title: "Motion (walk alarms)",
                    explanation: "Walk-to-dismiss alarms count about fifteen steps using Motion & Fitness. QR alarms only need the camera when an alarm rings.",
                    isGranted: motionOK,
                    denied: motionDenied,
                    isRequesting: requestingMotion,
                    allowTitle: "Allow Motion & Fitness",
                    onAllow: { Task { await requestMotion() } },
                    settingsHint: "Motion & Fitness for Still is off. Turn it on in Settings → Still to use walk dismiss."
                )

                if #available(iOS 26.0, *) {
                    permissionCard(
                        title: "System alarms",
                        explanation: "On iOS 26 or later, Still can schedule real alarms that ring through Sleep Focus and Do Not Disturb—not just a notification. They keep ringing if you leave the app; you still stop them only by walking fifteen steps or scanning your QR code after you tap Stop on the system alarm.",
                        isGranted: alarmKitAuthorized,
                        denied: alarmKitDenied,
                        isRequesting: requestingAlarmKit,
                        allowTitle: "Allow alarms",
                        onAllow: { Task { await triggerAlarmKitRequest() } },
                        settingsHint: "Alarm access for Still is off. Turn it on in Settings → Still to use full-screen alarms."
                    )
                }

                if !MotionStepAuthorization.isStepCountingAvailable {
                    Text("Step counting is not available on this device; walk dismiss will be limited. You can still use Focus and QR alarms.")
                        .font(.footnote)
                        .foregroundStyle(Tokens.ColorName.textTertiary)
                }

                PrimaryButton(title: "Continue", isDisabled: !canContinue) {
                    StillHaptics.success()
                    onFinished()
                }
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
            .padding(.vertical, Tokens.Spacing.xxl)
        }
        .background(Tokens.ColorName.backgroundPrimary.ignoresSafeArea())
        .onAppear { refreshStatuses() }
    }

    private var introCopy: some View {
        let head = Text("Still has two tabs: ") + Text("Focus").fontWeight(.semibold)
        let mid = Text(" shields apps and sites you choose using Screen Time, and ")
            + Text("Alarm").fontWeight(.semibold)
        let tail = Text(
            " wakes you with a QR scan or a short walk. Both need the right access to work on your device."
        )
        return (head + mid + tail)
            .font(.body)
            .foregroundStyle(Tokens.ColorName.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func refreshStatuses() {
        familyStatus = FocusAuthorization.authorizationStatus()
        motionStatus = MotionStepAuthorization.status()
        if #available(iOS 26.0, *) {
            switch AlarmManager.shared.authorizationState {
            case .authorized:
                alarmKitAuthorized = true
                alarmKitDenied = false
            case .denied:
                alarmKitAuthorized = false
                alarmKitDenied = true
            default:
                alarmKitAuthorized = false
                alarmKitDenied = false
            }
        }
    }

    private func requestScreenTime() async {
        requestingFamily = true
        defer {
            requestingFamily = false
            refreshStatuses()
        }
        do {
            try await FocusAuthorization.requestAuthorization()
            StillHaptics.selectionChanged()
        } catch {
            StillHaptics.warning()
        }
    }

    private func requestMotion() async {
        requestingMotion = true
        defer {
            requestingMotion = false
            refreshStatuses()
        }
        await MotionStepAuthorization.requestAccess()
        StillHaptics.selectionChanged()
    }

    private func triggerAlarmKitRequest() async {
        guard #available(iOS 26.0, *) else { return }
        requestingAlarmKit = true
        defer {
            requestingAlarmKit = false
            refreshStatuses()
        }
        do {
            _ = try await AlarmManager.shared.requestAuthorization()
            StillHaptics.selectionChanged()
        } catch {
            StillHaptics.warning()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        StillHaptics.lightImpact()
    }

    @ViewBuilder
    private func permissionCard(
        title: String,
        explanation: String,
        isGranted: Bool,
        denied: Bool,
        isRequesting: Bool,
        allowTitle: String,
        onAllow: @escaping () -> Void,
        settingsHint: String
    ) -> some View {
        CalmCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isGranted {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Tokens.ColorName.textPrimary)
                } else {
                    if denied {
                        Text(settingsHint)
                            .font(.footnote)
                            .foregroundStyle(Tokens.ColorName.dangerMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        SecondaryButton(title: "Open Settings") {
                            openSettings()
                        }
                    } else {
                        PrimaryButton(title: allowTitle, isLoading: isRequesting, isDisabled: isRequesting) {
                            onAllow()
                        }
                    }
                }
            }
        }
    }
}
