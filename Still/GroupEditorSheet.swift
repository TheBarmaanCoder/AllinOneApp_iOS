import FamilyControls
import SwiftUI

struct GroupEditorSheet: View {
    enum Mode {
        case create
        case edit(StoredFocusGroup)
    }

    let mode: Mode
    var onClose: () -> Void

    @State private var name: String = ""
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)

                    SecondaryButton(title: "Choose apps & sites") {
                        showPicker = true
                    }

                    if selectionItemCount == 0 {
                        Text("Choose at least one app, category, or site before saving.")
                            .font(.footnote)
                            .foregroundStyle(Tokens.ColorName.dangerMuted)
                    }

                    PrimaryButton(
                        title: mode.isCreate ? "Save group" : "Update",
                        isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectionItemCount == 0
                    ) {
                        save()
                    }

                    if !mode.isCreate {
                        SecondaryButton(title: "Delete group") {
                            delete()
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.bottom, Tokens.Spacing.xxl)
            }
            .background(Tokens.ColorName.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(mode.isCreate ? "New group" : "Edit group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        StillHaptics.softImpact()
                        dismiss()
                    }
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                }
            }
            .onAppear {
                if case let .edit(g) = mode {
                    name = g.name
                    if let decoded = try? SelectionCodec.decode(g.selectionData) {
                        selection = decoded
                    }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        }
    }

    private var selectionItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private func save() {
        var list = FocusGroupStore.load()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard selectionItemCount > 0 else { return }
        guard let data = try? SelectionCodec.encode(selection) else { return }

        switch mode {
        case .create:
            let g = StoredFocusGroup(id: UUID(), name: trimmed, selectionData: data)
            list.append(g)
        case let .edit(existing):
            if let idx = list.firstIndex(where: { $0.id == existing.id }) {
                list[idx] = StoredFocusGroup(id: existing.id, name: trimmed, selectionData: data)
            }
        }
        FocusGroupStore.save(list)
        CloudPreferencesSync.schedulePushDebounced()
        StillHaptics.success()
        onClose()
        dismiss()
    }

    private func delete() {
        guard case let .edit(existing) = mode else { return }
        var list = FocusGroupStore.load()
        list.removeAll { $0.id == existing.id }
        FocusGroupStore.save(list)
        CloudPreferencesSync.schedulePushDebounced()
        StillHaptics.warning()
        onClose()
        dismiss()
    }
}

private extension GroupEditorSheet.Mode {
    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }
}
