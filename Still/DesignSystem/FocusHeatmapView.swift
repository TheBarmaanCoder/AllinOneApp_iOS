import SwiftUI

/// GitHub-style monthly contribution grid showing daily focus intensity.
struct FocusHeatmapView: View {
    @State private var monthOffset = 0
    @State private var selectedDay: (day: Int, seconds: TimeInterval)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var displayDate: Date {
        Calendar.current.date(byAdding: .month, value: -monthOffset, to: Date()) ?? Date()
    }

    private var year: Int { Calendar.current.component(.year, from: displayDate) }
    private var month: Int { Calendar.current.component(.month, from: displayDate) }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayDate)
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: displayDate)?.count ?? 30
    }

    /// Weekday of the 1st (0 = Monday in our grid).
    private var firstWeekdayOffset: Int {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: displayDate)
        comps.day = 1
        guard let firstDay = cal.date(from: comps) else { return 0 }
        let weekday = cal.component(.weekday, from: firstDay)
        // .weekday: 1 = Sunday. Convert to Monday-start: Mon=0 … Sun=6
        return (weekday + 5) % 7
    }

    private var monthData: [Int: TimeInterval] {
        DailyFocusLog.monthData(year: year, month: month)
    }

    /// Max seconds in any day this month (for color intensity scaling).
    private var maxSeconds: TimeInterval {
        max(1, monthData.values.max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            header

            weekdayHeader

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(0..<(firstWeekdayOffset + daysInMonth), id: \.self) { index in
                    if index < firstWeekdayOffset {
                        Color.clear.frame(height: 28)
                    } else {
                        let day = index - firstWeekdayOffset + 1
                        let secs = monthData[day] ?? 0
                        dayCell(day: day, seconds: secs)
                    }
                }
            }

            if let selected = selectedDay {
                HStack(spacing: Tokens.Spacing.xs) {
                    Text("\(monthTitle.prefix(3)) \(selected.day)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Tokens.ColorName.textSecondary)
                    Spacer()
                    Text(formattedDuration(selected.seconds))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Tokens.ColorName.textPrimary)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { monthOffset += 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.ColorName.textTertiary)
            }

            Spacer()

            Text(monthTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tokens.ColorName.textPrimary)

            Spacer()

            Button {
                guard monthOffset > 0 else { return }
                withAnimation(.easeOut(duration: 0.2)) { monthOffset -= 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(monthOffset > 0 ? Tokens.ColorName.textTertiary : .clear)
            }
            .disabled(monthOffset <= 0)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Tokens.ColorName.textTertiary)
                    .frame(height: 16)
            }
        }
    }

    private func dayCell(day: Int, seconds: TimeInterval) -> some View {
        let intensity = intensityForDay(seconds)
        let isSelected = selectedDay?.day == day

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if selectedDay?.day == day {
                    selectedDay = nil
                } else {
                    selectedDay = (day, seconds)
                }
            }
            StillHaptics.selectionChanged()
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(cellColor(intensity: intensity))
                .frame(height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(isSelected ? Tokens.ColorName.accent : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }


    private func intensityForDay(_ seconds: TimeInterval) -> Double {
        let minSeconds: TimeInterval = 1800   // 30 minutes
        let maxSeconds: TimeInterval = 36000  // 10 hours

        guard seconds > minSeconds else { return 0 }
        if seconds >= maxSeconds { return 1 }

        let normalized = (seconds - minSeconds) / (maxSeconds - minSeconds)
        return max(0.08, min(1, normalized))
    }

    private func cellColor(intensity: Double) -> Color {
        if intensity <= 0 {
            return Tokens.ColorName.surfaceMuted
        }
        let theme = StillTheme.current
        if theme == .dark {
            return Color.white.opacity(intensity * 0.85 + 0.1)
        } else {
            return Color.black.opacity(intensity * 0.7 + 0.08)
        }
    }

    private func formattedDuration(_ t: TimeInterval) -> String {
        let hours = Int(t) / 3600
        let minutes = (Int(t) % 3600) / 60
        if t < 60 { return "< 1m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
