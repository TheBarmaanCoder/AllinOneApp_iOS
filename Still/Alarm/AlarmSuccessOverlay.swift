import SwiftUI

struct AlarmSuccessOverlay: View {
    let dismissMode: AlarmDismissMode
    var onDone: () -> Void

    @State private var phase: Phase = .icon

    private enum Phase {
        case icon, morph, check, done
    }

    private var iconName: String {
        switch dismissMode.normalized {
        case .qr: return "qrcode.viewfinder"
        default: return "sunrise.fill"
        }
    }

    private var usesHierarchical: Bool {
        dismissMode.normalized != .qr
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                Circle()
                    .stroke(Color.green, lineWidth: 4)
                    .frame(width: 120, height: 120)
                    .scaleEffect(phase == .icon ? 0.5 : 1)
                    .opacity(phase == .icon ? 0 : 1)

                Group {
                    if phase == .check || phase == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(usesHierarchical ? .orange : .white)
                            .symbolRenderingMode(usesHierarchical ? .hierarchical : .monochrome)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: phase)

            VStack {
                Spacer()
                Text(phase == .check || phase == .done ? "Alarm dismissed" : "")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .opacity(phase == .check || phase == .done ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: phase)
                    .padding(.bottom, 80)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            phase = .morph
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            phase = .check
            StillHaptics.success()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            phase = .done
            onDone()
        }
    }
}
