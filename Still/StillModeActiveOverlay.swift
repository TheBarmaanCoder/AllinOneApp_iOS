import SwiftUI

struct StillModeActiveOverlay: View {
    @ObservedObject var controller: StillModeController
    @EnvironmentObject private var session: FocusSessionController
    @State private var elapsed: TimeInterval = 0
    @State private var showEntryAnimation = true
    @State private var showScanner = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showEntryAnimation {
                StillModeEntryAnimation {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showEntryAnimation = false
                    }
                }
                .transition(.opacity)
            } else if controller.pendingExit {
                StillModeExitFlow(controller: controller)
                    .transition(.opacity)
            } else {
                activeContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showEntryAnimation)
        .animation(.easeInOut(duration: 0.3), value: controller.pendingExit)
        .onReceive(timer) { _ in
            elapsed = controller.elapsedSeconds
            session.syncCheatState()
        }
        .onAppear {
            elapsed = controller.elapsedSeconds
        }
    }

    private var activeContent: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "moon.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))

            VStack(spacing: 8) {
                Text("Still Mode")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("Your phone is in focus")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            if session.isCheatActive {
                Text(formattedCheat(session.cheatRemainingSeconds))
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())

                Button {
                    session.endCheatAndReblock()
                    StillHaptics.success()
                } label: {
                    Label("Restore Still Mode", systemImage: "lock.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            } else {
                Text(formattedTime(elapsed))
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                scanButton
            }

            Spacer()

            VStack(spacing: 12) {
                Text("Or scan with your camera app to exit")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showScanner) {
            StillModeScannerSheet {
                showScanner = false
                controller.requestExit()
            } onCancel: {
                showScanner = false
            }
        }
    }

    private var scanButton: some View {
        Button {
            StillHaptics.lightImpact()
            showScanner = true
        } label: {
            Label("Scan QR to exit", systemImage: "qrcode.viewfinder")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: 260)
                .padding(.vertical, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func formattedTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formattedCheat(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - In-app QR scanner for Still Mode exit

private struct StillModeScannerSheet: View {
    var onMatch: () -> Void
    var onCancel: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: Tokens.Spacing.lg) {
                    Text("Scan your QR code to exit Still Mode")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)

                    QRScannerRepresentable { text in
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard let url = URL(string: trimmed),
                              url.scheme == AlarmConstants.qrURLScheme,
                              url.host == "dismiss",
                              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
                              AlarmQRTokenStore.matches(token)
                        else {
                            errorMessage = "That code did not match. Try again."
                            return
                        }
                        onMatch()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous))
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Entry animation (lock icon → moon)

private struct StillModeEntryAnimation: View {
    var onDone: () -> Void

    @State private var phase: Phase = .lock

    private enum Phase {
        case lock, morph, moon, done
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.6), lineWidth: 4)
                    .frame(width: 120, height: 120)
                    .scaleEffect(phase == .lock ? 0.5 : 1)
                    .opacity(phase == .lock ? 0 : 1)

                Group {
                    if phase == .moon || phase == .done {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: phase)

            VStack {
                Spacer()
                Text(phase == .moon || phase == .done ? "Still Mode activated" : "")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .opacity(phase == .moon || phase == .done ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: phase)
                    .padding(.bottom, 80)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            phase = .morph
            StillHaptics.success()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            phase = .moon
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            phase = .done
            onDone()
        }
    }
}
