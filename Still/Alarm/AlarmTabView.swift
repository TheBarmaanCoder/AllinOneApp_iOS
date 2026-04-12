import SwiftUI
import UIKit

private struct QRSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct AlarmTabView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var alarmStore: AlarmStore
    @State private var editorMode: AlarmEditorSheet.Mode?
    @State private var alarmRevocationKind: PermissionRevocationTracker.AlarmRevocationKind?
    @State private var qrSharePayload: QRSharePayload?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                    Text("Alarms")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Tokens.ColorName.textPrimary)

                    if alarmStore.alarms.isEmpty {
                        EmptyState(
                            title: "No alarms yet",
                            message: emptyAlarmsMessage,
                            actionTitle: "Add alarm"
                        ) {
                            editorMode = .create
                        }
                    } else {
                        alarmList

                        PrimaryButton(title: "Add alarm") {
                            editorMode = .create
                        }
                    }

                }
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.vertical, Tokens.Spacing.screenVertical)
            }
            .background(Tokens.ColorName.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $editorMode) { mode in
            AlarmEditorSheet(mode: mode, onClose: { editorMode = nil }, alarmStore: alarmStore)
        }
        .alert(alarmRevocationAlertTitle, isPresented: Binding(
            get: { alarmRevocationKind != nil },
            set: { if !$0 { alarmRevocationKind = nil } }
        )) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
                StillHaptics.lightImpact()
            }
            if alarmRevocationKind == .notifications {
                Button("Allow in Still") {
                    Task {
                        _ = await AlarmScheduler.requestAuthorizationIfNeeded()
                        await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms)
                        await evaluateAlarmPermissionRevocation()
                    }
                }
            }
            if #available(iOS 26.0, *) {
                if alarmRevocationKind == .alarmKit {
                    Button("Allow alarms") {
                        Task {
                            _ = try? await AlarmKitScheduler.requestAuthorization()
                            await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms)
                            await evaluateAlarmPermissionRevocation()
                        }
                    }
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(alarmRevocationAlertMessage)
        }
        .task {
            if !AlarmBootstrap.usesAlarmKitThisDevice {
                _ = await AlarmScheduler.requestAuthorizationIfNeeded()
            }
            await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms)
            await evaluateAlarmPermissionRevocation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await evaluateAlarmPermissionRevocation() }
        }
        .sheet(item: $qrSharePayload) { payload in
            ActivityShareSheet(activityItems: [payload.image])
        }
    }

    // MARK: - Alarm list with swipe-to-delete

    private var alarmList: some View {
        VStack(spacing: 0) {
            ForEach(alarmStore.alarms) { alarm in
                alarmRow(alarm)
                    .background(Tokens.ColorName.backgroundSecondary)
                    .swipeToDelete {
                        alarmStore.delete(id: alarm.id)
                    }
                if alarm.id != alarmStore.alarms.last?.id {
                    Divider().background(Tokens.ColorName.separator)
                        .padding(.horizontal, Tokens.Spacing.lg)
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                .fill(Tokens.ColorName.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous))
    }

    private var emptyAlarmsMessage: String {
        if AlarmBootstrap.usesAlarmKitThisDevice {
            return "Create an alarm. It rings like a real clock—even when locked or in Do Not Disturb—and nags you every 30 seconds until you dismiss it."
        }
        return "Create an alarm and allow notifications when asked so Still can alert you."
    }

    private var alarmRevocationAlertTitle: String {
        guard let kind = alarmRevocationKind, kind != .none else { return "" }
        switch kind {
        case .alarmKit:
            return "System alarms turned off"
        case .notifications:
            return "Notifications turned off"
        case .none:
            return ""
        }
    }

    private var alarmRevocationAlertMessage: String {
        guard let kind = alarmRevocationKind, kind != .none else { return "" }
        switch kind {
        case .alarmKit:
            return "Still uses system alarms so your alarm can ring through Do Not Disturb and Sleep Focus until you dismiss it. Turn alarm access back on under Settings → Still."
        case .notifications:
            return "On this iOS version Still uses notifications to sound alarms. Turn notifications back on under Settings → Still so alarms can reach you."
        case .none:
            return ""
        }
    }

    private func evaluateAlarmPermissionRevocation() async {
        let kind = await PermissionRevocationTracker.refreshAlarmRelatedRevocation()
        guard kind != .none else { return }
        await MainActor.run {
            alarmRevocationKind = kind
        }
    }

    // MARK: - QR card (kept for Settings)

    var qrCard: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                Text("Your dismiss QR")
                    .font(.headline)
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                Text("Print this once or save a photo. Place it away from your bed and scan it to stop QR-type alarms.")
                    .font(.subheadline)
                    .foregroundStyle(Tokens.ColorName.textSecondary)

                HStack {
                    Spacer()
                    QRCodeImageView(content: AlarmQRTokenStore.dismissURLString, dimension: 180)
                    Spacer()
                }

                SecondaryButton(title: "Share QR image") {
                    let url = AlarmQRTokenStore.dismissURLString
                    if let image = QRCodeImageView.qrUIImage(content: url, dimension: 768) {
                        StillHaptics.lightImpact()
                        qrSharePayload = QRSharePayload(image: image)
                    }
                }
            }
        }
    }

    private func alarmRow(_ alarm: StoredAlarm) -> some View {
        HStack(alignment: .center, spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                Text(timeString(alarm))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text(alarm.label.isEmpty ? alarm.dismissMode.title : alarm.label)
                    .font(.subheadline)
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                Text(weekdaysString(alarm.weekdays))
                    .font(.caption)
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { on in
                    StillHaptics.selectionChanged()
                    var a = alarm
                    a.isEnabled = on
                    alarmStore.update(a)
                }
            ))
            .labelsHidden()
            .tint(Tokens.ColorName.textPrimary)
            Button {
                StillHaptics.lightImpact()
                editorMode = .edit(alarm)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Tokens.Spacing.sm)
        .padding(.horizontal, Tokens.Spacing.lg)
    }

    private func timeString(_ alarm: StoredAlarm) -> String {
        var dc = DateComponents()
        dc.hour = alarm.hour
        dc.minute = alarm.minute
        let cal = Calendar.current
        let d = cal.date(from: dc) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    private func weekdaysString(_ days: Set<Int>) -> String {
        let sorted = days.sorted()
        if sorted.count == 7 { return "Every day" }
        if sorted == [2, 3, 4, 5, 6] { return "Weekdays" }
        if sorted == [1, 7] { return "Weekends" }
        return sorted.map { StoredAlarm.weekdaySymbolsShort[$0 - 1] }.joined(separator: ", ")
    }
}

extension AlarmEditorSheet.Mode: Identifiable {
    var id: String {
        switch self {
        case .create: return "create"
        case let .edit(a): return a.id.uuidString
        }
    }
}
