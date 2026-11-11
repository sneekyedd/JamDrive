import SwiftUI

@main
struct JamDriveApp: App {
    @StateObject private var settings: DriveSettings
    @StateObject private var controller: DriveController

    init() {
        let settings = DriveSettings()
        let controller = DriveController(settings: settings)
        _settings = StateObject(wrappedValue: settings)
        _controller = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(controller)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
