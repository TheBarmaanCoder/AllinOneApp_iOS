import SwiftUI
import UIKit

private struct QRSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct AlarmTabView: View {
    @ObservedObject var alarmStore: AlarmStore
    @State private var editorMode: AlarmEditorSheet.Mode?
    @State private var notificationDenied = false
    @State private var qrSharePayload: QRSharePayload?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                    qrCard

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
                        VStack(spacing: 0) {
                            ForEach(alarmStore.alarms) { alarm in
                                alarmRow(alarm)
                                if alarm.id != alarmStore.alarms.last?.id {
                                    Divider().background(Tokens.ColorName.separator)
                                }
                            }
                        }
                        .padding(.horizontal, Tokens.Spacing.lg)
                        .padding(.vertical, Tokens.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
                                .fill(Tokens.ColorName.backgroundSecondary)
                                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
                        )

                        PrimaryButton(title: "Add alarm") {
                            editorMode = .create
                        }
                    }

                    if notificationDenied {
                        Text(notificationDeniedMessage)
                            .font(.footnote)
                            .foregroundStyle(Tokens.ColorName.dangerMuted)
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
        .task {
            if AlarmBootstrap.usesAlarmKitThisDevice {
                notificationDenied = false
            } else {
                let ok = await AlarmScheduler.requestAuthorizationIfNeeded()
                notificationDenied = !ok
            }
            await AlarmBootstrap.rescheduleAll(alarms: alarmStore.alarms)
        }
        .sheet(item: $qrSharePayload) { payload in
            ActivityShareSheet(activityItems: [payload.image])
        }
    }

    private var emptyAlarmsMessage: String {
        if AlarmBootstrap.usesAlarmKitThisDevice {
            return "Create an alarm. With system alarms, your phone rings like a real clock—even when it is locked or in Do Not Disturb—until you finish your walk or QR challenge."
        }
        return "Create an alarm and allow notifications when asked so Still can alert you."
    }

    private var notificationDeniedMessage: String {
        "Notifications are off. Enable them in Settings → Still → Notifications to hear alarms on this iOS version."
    }

    private var qrCard: some View {
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
        .contextMenu {
            Button(role: .destructive) {
                alarmStore.delete(id: alarm.id)
            } label: {
                Label("Delete alarm", systemImage: "trash")
            }
        }
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
