import SwiftUI

@main
struct AutoSortApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings Window
        Settings {
            SettingsView()
        }
    }
}
