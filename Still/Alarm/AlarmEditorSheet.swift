import SwiftUI

struct AlarmEditorSheet: View {
    enum Mode {
        case create
        case edit(StoredAlarm)
    }

    let mode: Mode
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var alarmStore: AlarmStore

    @State private var label: String = ""
    @State private var time: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var weekdays: Set<Int> = Set(1 ... 7)
    @State private var dismissMode: AlarmDismissMode = .simple
    @State private var ringtone: StillAlarmRingtoneOption = .default

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                }

                Section("Repeat") {
                    ForEach(1 ... 7, id: \.self) { day in
                        Toggle(isOn: Binding(
                            get: { weekdays.contains(day) },
                            set: { on in
                                StillHaptics.selectionChanged()
                                if on { weekdays.insert(day) } else { weekdays.remove(day) }
                            }
                        )) {
                            Text(weekdayTitle(day))
                        }
                        .tint(.primary)
                    }
                }

                Section("Dismiss") {
                    Picker("How to stop", selection: $dismissMode) {
                        ForEach(AlarmDismissMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.inline)
                    Text(dismissMode.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("Sound", selection: $ringtone) {
                        ForEach(StillAlarmRingtoneOption.allCases) { r in
                            Text(r.title).tag(r)
                        }
                    }
                    Text(soundFootnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Sound")
                }

                Section("Label") {
                    TextField("Optional", text: $label)
                }
            }
            .navigationTitle(mode.isCreate ? "New alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        StillHaptics.softImpact()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(weekdays.isEmpty)
                }
            }
            .onAppear {
                if case let .edit(a) = mode {
                    label = a.label
                    dismissMode = a.dismissMode
                    weekdays = a.weekdays
                    ringtone = StillAlarmRingtoneOption(rawValue: a.ringtoneID) ?? .default
                    var dc = DateComponents()
                    dc.hour = a.hour
                    dc.minute = a.minute
                    time = Calendar.current.date(from: dc) ?? time
                }
            }
        }
    }

    private var soundFootnote: String {
        if #available(iOS 26.0, *) {
            return "On iOS 26 or later—with alarm permission—this tone plays as a full-screen system alarm. On older iOS versions, notifications use the default alert sound."
        }
        return "The tone you pick is used for system alarms on iOS 26 or newer. Older iOS versions use standard notification sounds."
    }

    private func weekdayTitle(_ day: Int) -> String {
        guard day >= 1, day <= 7 else { return "" }
        return StoredAlarm.weekdaySymbolsShort[day - 1]
    }

    private func save() {
        let cal = Calendar.current
        let h = cal.component(.hour, from: time)
        let m = cal.component(.minute, from: time)
        switch mode {
        case .create:
            let alarm = StoredAlarm(
                id: UUID(),
                hour: h,
                minute: m,
                label: label,
                weekdays: weekdays,
                isEnabled: true,
                dismissMode: dismissMode,
                ringtoneID: ringtone.storageID
            )
            alarmStore.add(alarm)
        case let .edit(existing):
            var a = existing
            a.hour = h
            a.minute = m
            a.label = label
            a.weekdays = weekdays
            a.dismissMode = dismissMode
            a.ringtoneID = ringtone.storageID
            alarmStore.update(a)
        }
        StillHaptics.success()
        onClose()
        dismiss()
    }
}

private extension AlarmEditorSheet.Mode {
    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }
}
