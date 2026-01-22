import AppKit
import Foundation
import UserNotifications

/// Handles user notifications for file sorting events
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    // MARK: - Permission

    /// Requests notification permissions from the user
    func requestPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    /// Checks if notifications are authorized
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - Sending Notifications

    /// Sends a notification when a file is successfully sorted
    func sendFileSortedNotification(record: SortedFileRecord) {
        let content = UNMutableNotificationContent()
        content.title = "File Sorted"
        content.body = "\(record.filename) moved to \(record.destinationDescription)"
        content.sound = .default
        content.categoryIdentifier = Constants.Notifications.fileSorted
        content.userInfo = [
            Constants.Notifications.filePathKey: record.destinationPath
        ]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    /// Sends an error notification
    func sendErrorNotification(filename: String, error: String) {
        let content = UNMutableNotificationContent()
        content.title = "Sorting Failed"
        content.body = "Could not sort \(filename): \(error)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    // MARK: - Notification Actions

    /// Sets up notification categories and actions
    func setupNotificationCategories() {
        let showInFinderAction = UNNotificationAction(
            identifier: "showInFinder",
            title: "Show in Finder",
            options: [.foreground]
        )

        let fileSortedCategory = UNNotificationCategory(
            identifier: Constants.Notifications.fileSorted,
            actions: [showInFinderAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        notificationCenter.setNotificationCategories([fileSortedCategory])
    }

    /// Handles notification response (e.g., clicking the notification)
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        if let filePath = userInfo[Constants.Notifications.filePathKey] as? String {
            let url = URL(fileURLWithPath: filePath)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
