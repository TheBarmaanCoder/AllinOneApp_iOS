import AudioToolbox
import AVFoundation
import Foundation

/// Repeating alert while an alarm is ringing (foreground). Notification already played one system sound.
final class AlarmSoundPlayer {
    private var timer: Timer?

    var isRunning: Bool { timer != nil }

    func start() {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(1005)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        RunLoop.main.add(timer!, forMode: .common)
        AudioServicesPlaySystemSound(1005)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
