import AlarmKit
import AVFoundation
import FamilyControls
import SwiftUI
import UIKit
import UserNotifications

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var familyStatus: AuthorizationStatus = FocusAuthorization.authorizationStatus()
    @State private var requestingFamily = false
    @State private var requestingCamera = false
    @State private var requestingNotifications = false
    @State private var requestingAlarmKit = false
    @State private var alarmKitAuthorized = false
    @State private var alarmKitDenied = false
    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    private var screenTimeOK: Bool {
        familyStatus == .approved
    }

    private var notificationOK: Bool {
        switch notificationAuthStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private var notificationDenied: Bool {
        notificationAuthStatus == .denied
    }

    private var canContinue: Bool {
        screenTimeOK && notificationOK
    }

    private var familyDenied: Bool {
        familyStatus == .denied
    }

    private var cameraOK: Bool {
        cameraStatus == .authorized
    }

    private var cameraDenied: Bool {
        cameraStatus == .denied || cameraStatus == .restricted
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
                    title: "Camera (QR alarms & Still Mode)",
                    explanation: "Still uses the camera to scan your printed QR code — both for alarm dismiss and to enter Still Mode. Images are not saved or uploaded.",
                    isGranted: cameraOK,
                    denied: cameraDenied,
                    isRequesting: requestingCamera,
                    allowTitle: "Allow Camera",
                    onAllow: { Task { await requestCamera() } },
                    settingsHint: "Camera access for Still is off. Turn it on in Settings → Still to use QR features."
                )

                permissionCard(
                    title: "Notifications",
                    explanation: "Still sends follow-up alarm alerts if you dismiss without completing the challenge. No marketing — only alarm follow-ups.",
                    isGranted: notificationOK,
                    denied: notificationDenied,
                    isRequesting: requestingNotifications,
                    allowTitle: "Allow Notifications",
                    onAllow: { Task { await requestNotifications() } },
                    settingsHint: "Notifications for Still are off. Turn them on in Settings → Still so follow-up alarms can play."
                )

                if #available(iOS 26.0, *) {
                    permissionCard(
                        title: "System alarms",
                        explanation: "Still can schedule real alarms that ring through Sleep Focus and Do Not Disturb — not just a notification. They keep ringing until you open the app and dismiss them.",
                        isGranted: alarmKitAuthorized,
                        denied: alarmKitDenied,
                        isRequesting: requestingAlarmKit,
                        allowTitle: "Allow alarms",
                        onAllow: { Task { await triggerAlarmKitRequest() } },
                        settingsHint: "Alarm access for Still is off. Turn it on in Settings → Still to use full-screen alarms."
                    )
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
        .onAppear {
            refreshStatuses()
            Task { await refreshNotificationStatus() }
        }
    }

    private var introCopy: some View {
        let head = Text("Still has three tabs: ") + Text("Focus").fontWeight(.semibold)
        let mid = Text(" shields apps you choose, ")
            + Text("Alarm").fontWeight(.semibold)
        let tail = Text(
            " wakes you and won't stop until you're up, and "
        ) + Text("Settings").fontWeight(.semibold) + Text(" has your QR code.")
        return (head + mid + tail)
            .font(.body)
            .foregroundStyle(Tokens.ColorName.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func refreshStatuses() {
        familyStatus = FocusAuthorization.authorizationStatus()
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
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

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationAuthStatus = settings.authorizationStatus
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

    private func requestCamera() async {
        requestingCamera = true
        defer {
            requestingCamera = false
            refreshStatuses()
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            StillHaptics.selectionChanged()
        case .notDetermined:
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
            }
            if granted {
                StillHaptics.selectionChanged()
            } else {
                StillHaptics.warning()
            }
        case .denied, .restricted:
            StillHaptics.warning()
        @unknown default:
            StillHaptics.warning()
        }
    }

    private func requestNotifications() async {
        requestingNotifications = true
        let granted = await AlarmScheduler.requestAuthorizationIfNeeded()
        await refreshNotificationStatus()
        requestingNotifications = false
        if granted {
            StillHaptics.selectionChanged()
        } else {
            StillHaptics.warning()
        }
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
