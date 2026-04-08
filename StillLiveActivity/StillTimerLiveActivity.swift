import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct StillTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StillTimerAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    expandedView(context: context)
                }
            } compactLeading: {
                Image(systemName: iconName(for: context.attributes.mode))
                    .font(.caption2)
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text(timerInterval: timerRange(context: context), countsDown: context.state.endDate != nil)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 48)
            } minimal: {
                Image(systemName: iconName(for: context.attributes.mode))
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<StillTimerAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: context.attributes.mode))
                .font(.title3)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(timerInterval: timerRange(context: context), countsDown: context.state.endDate != nil)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.black)
    }

    @ViewBuilder
    private func expandedView(context: ActivityViewContext<StillTimerAttributes>) -> some View {
        VStack(spacing: 4) {
            Text(context.attributes.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))

            Text(timerInterval: timerRange(context: context), countsDown: context.state.endDate != nil)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
    }

    // MARK: - Helpers

    private func iconName(for mode: StillTimerAttributes.Mode) -> String {
        switch mode {
        case .focus: return "moon.fill"
        case .stillMode: return "lock.fill"
        case .cheat: return "clock.badge.exclamationmark"
        }
    }

    private func timerRange(context: ActivityViewContext<StillTimerAttributes>) -> ClosedRange<Date> {
        let start = context.state.startDate
        let end = context.state.endDate ?? Date.distantFuture
        return start...end
    }
}
