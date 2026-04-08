import SwiftUI
import WidgetKit

@main
struct StillLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            StillTimerLiveActivity()
        }
    }
}
