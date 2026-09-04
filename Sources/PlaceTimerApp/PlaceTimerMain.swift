import PlaceTimerKit
import SwiftUI

@main
struct PlaceTimerApp: App {
    @NSApplicationDelegateAdaptor(PlaceTimerAppDelegate.self) private var delegate

    var body: some Scene {
        PlaceTimerScene(coordinator: delegate.coordinator)
    }
}
