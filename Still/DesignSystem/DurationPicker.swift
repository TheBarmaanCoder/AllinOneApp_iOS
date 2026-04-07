import SwiftUI

enum DurationBarPreset: Equatable {
    case thirty
    case oneHour
    case ninety
    case twoHours
    case other
}

struct DurationBar: View {
    @Binding var preset: DurationBarPreset
    @Binding var otherHours: Int
    @Binding var otherMinutes: Int
    @Binding var showOtherSheet: Bool

    private let chips: [(DurationBarPreset, String)] = [
        (.thirty, "30 min"),
        (.oneHour, "1 hr"),
        (.ninety, "1h 30"),
        (.twoHours, "2 hr"),
        (.other, "Other"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            Text("Duration")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textSecondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Tokens.Spacing.sm),
                    GridItem(.flexible(), spacing: Tokens.Spacing.sm),
                    GridItem(.flexible(), spacing: Tokens.Spacing.sm),
                ],
                spacing: Tokens.Spacing.sm
            ) {
                ForEach(chips, id: \.0) { item in
                    let (kind, label) = item
                    Button {
                        StillHaptics.selectionChanged()
                        if kind == .other {
                            showOtherSheet = true
                        } else {
                            preset = kind
                        }
                    } label: {
                        Text(otherLabelIfNeeded(kind: kind, defaultLabel: label))
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Tokens.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                                    .fill(isSelected(kind) ? Tokens.ColorName.textPrimary : Tokens.ColorName.surfaceMuted)
                            )
                            .foregroundStyle(isSelected(kind) ? Tokens.ColorName.backgroundPrimary : Tokens.ColorName.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func isSelected(_ kind: DurationBarPreset) -> Bool {
        preset == kind
    }

    private func otherLabelIfNeeded(kind: DurationBarPreset, defaultLabel: String) -> String {
        guard kind == .other, preset == .other else { return defaultLabel }
        let m = min(23 * 60 + 59, max(1, otherHours * 60 + otherMinutes))
        let h = m / 60
        let minRem = m % 60
        if h > 0, minRem > 0 {
            return "\(h)h \(minRem)m"
        }
        if h > 0 { return "\(h)h" }
        return "\(minRem)m"
    }
}

struct OtherDurationSheet: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    var onCancel: () -> Void
    var onDone: () -> Void

    @State private var localHours: Int = 0
    @State private var localMinutes: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: Tokens.Spacing.lg) {
                HStack(alignment: .center, spacing: Tokens.Spacing.sm) {
                    Picker("Hours", selection: $localHours) {
                        ForEach(0 ..< 24, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .labelsHidden()
                    .onChange(of: localHours) { _ in
                        StillHaptics.selectionChanged()
                    }

                    Text(localHours == 1 ? "hour" : "hours")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Tokens.ColorName.textSecondary)
                        .frame(minWidth: 52, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)

                    Picker("Minutes", selection: $localMinutes) {
                        ForEach(0 ..< 60, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .labelsHidden()
                    .onChange(of: localMinutes) { _ in
                        StillHaptics.selectionChanged()
                    }

                    Text(localMinutes == 1 ? "minute" : "minutes")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Tokens.ColorName.textSecondary)
                        .frame(minWidth: 64, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, Tokens.Spacing.md)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .background(Tokens.ColorName.backgroundPrimary)
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        StillHaptics.lightImpact()
                        onCancel()
                    }
                    .foregroundStyle(Tokens.ColorName.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        StillHaptics.softImpact()
                        hours = localHours
                        minutes = localMinutes
                        onDone()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Tokens.ColorName.textPrimary)
                }
            }
            .onAppear {
                localHours = hours
                localMinutes = minutes
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
