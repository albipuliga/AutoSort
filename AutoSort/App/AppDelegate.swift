import Foundation
import AppKit
import UserNotifications

/// App delegate handling notification responses and app lifecycle
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        NotificationService.shared.requestPermission()
        NotificationService.shared.setupNotificationCategories()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is "active" (menu bar apps are always active)
        completionHandler([.banner, .sound])
    }

    /// Handle notification interactions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationService.shared.handleNotificationResponse(response)
        completionHandler()
    }
}
