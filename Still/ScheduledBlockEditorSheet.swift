import FamilyControls
import SwiftUI

struct ScheduledBlockEditorSheet: View {
    enum Mode {
        case create
        case edit(ScheduledBlock)
    }

    let mode: Mode
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedWeekdays: Set<Int>
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selection: FamilyActivitySelection
    @State private var showPicker = false
    @State private var enabled: Bool
    private let editingID: UUID?

    private let weekdays: [(Int, String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    init(mode: Mode, onDone: @escaping () -> Void) {
        self.mode = mode
        self.onDone = onDone
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _selectedWeekdays = State(initialValue: [2, 3, 4, 5, 6])
            let cal = Calendar.current
            _startTime = State(initialValue: cal.date(from: DateComponents(hour: 9, minute: 0)) ?? Date())
            _endTime = State(initialValue: cal.date(from: DateComponents(hour: 17, minute: 0)) ?? Date())
            _selection = State(initialValue: FamilyActivitySelection())
            _enabled = State(initialValue: true)
            editingID = nil
        case .edit(let block):
            _name = State(initialValue: block.name)
            _selectedWeekdays = State(initialValue: block.weekdays)
            let cal = Calendar.current
            _startTime = State(initialValue: cal.date(from: DateComponents(hour: block.startHour, minute: block.startMin)) ?? Date())
            _endTime = State(initialValue: cal.date(from: DateComponents(hour: block.endHour, minute: block.endMin)) ?? Date())
            let sel = (try? SelectionCodec.decode(block.selectionData)) ?? FamilyActivitySelection()
            _selection = State(initialValue: sel)
            _enabled = State(initialValue: block.enabled)
            editingID = block.id
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Work hours", text: $name)
                }

                Section("Days") {
                    HStack(spacing: 6) {
                        ForEach(weekdays, id: \.0) { day, label in
                            Button {
                                StillHaptics.selectionChanged()
                                if selectedWeekdays.contains(day) {
                                    selectedWeekdays.remove(day)
                                } else {
                                    selectedWeekdays.insert(day)
                                }
                            } label: {
                                Text(label)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selectedWeekdays.contains(day)
                                                  ? Tokens.ColorName.accent
                                                  : Tokens.ColorName.surfaceMuted)
                                    )
                                    .foregroundStyle(selectedWeekdays.contains(day)
                                                     ? Tokens.ColorName.backgroundPrimary
                                                     : Tokens.ColorName.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Time") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section("Apps to block") {
                    Button {
                        showPicker = true
                    } label: {
                        HStack {
                            Text("Choose apps & sites")
                                .foregroundStyle(Tokens.ColorName.textPrimary)
                            Spacer()
                            Text(selectionSummary)
                                .font(.caption)
                                .foregroundStyle(Tokens.ColorName.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Tokens.ColorName.textTertiary)
                        }
                    }
                }

                if case .edit = mode {
                    Section {
                        Toggle("Enabled", isOn: $enabled)
                    }

                    Section {
                        Button("Delete block", role: .destructive) {
                            deleteBlock()
                        }
                    }
                }
            }
            .navigationTitle(editingID == nil ? "New Scheduled Block" : "Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBlock()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedWeekdays.isEmpty)
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        }
    }

    private var selectionSummary: String {
        let n = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        if n == 0 { return "None" }
        return n == 1 ? "1 item" : "\(n) items"
    }

    private func saveBlock() {
        guard let data = try? SelectionCodec.encode(selection) else { return }

        let cal = Calendar.current
        let sComps = cal.dateComponents([.hour, .minute], from: startTime)
        let eComps = cal.dateComponents([.hour, .minute], from: endTime)

        let block = ScheduledBlock(
            id: editingID ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            enabled: enabled,
            weekdays: selectedWeekdays,
            startMinute: (sComps.hour ?? 9) * 60 + (sComps.minute ?? 0),
            endMinute: (eComps.hour ?? 17) * 60 + (eComps.minute ?? 0),
            selectionData: data
        )

        var blocks = ScheduledBlockStore.load()
        if let idx = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[idx] = block
        } else {
            blocks.append(block)
        }
        ScheduledBlockStore.save(blocks)
        ScheduledBlockScheduler.rescheduleAll()
        CloudPreferencesSync.schedulePushDebounced()
        onDone()
        dismiss()
    }

    private func deleteBlock() {
        if let id = editingID {
            var blocks = ScheduledBlockStore.load()
            blocks.removeAll { $0.id == id }
            ScheduledBlockStore.save(blocks)
            ScheduledBlockScheduler.rescheduleAll()
            CloudPreferencesSync.schedulePushDebounced()
        }
        onDone()
        dismiss()
    }
}
