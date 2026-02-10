import Foundation

enum Constants {
    enum App {
        static let name = "AutoSort"
        static let bundleIdentifier = "com.autosort.app"
    }

    enum UserDefaultsKeys {
        static let appSettings = "appSettings"
        static let recentActivity = "recentActivity"
    }

    enum Notifications {
        static let fileSorted = "AutoSort.fileSorted"
        static let filePathKey = "filePath"
    }

    enum UI {
        static let menuBarShouldClose = Notification.Name("AutoSort.menuBarShouldClose")
        static let menuBarCloseDelay: TimeInterval = 0.25
        static let menuBarFadeDuration: TimeInterval = 0.2
    }

    enum FileWatcher {
        /// Coalescing window for filesystem events before performing a directory diff
        static let eventWindowInterval: TimeInterval = 0.2

        /// Debounce interval in seconds to wait for file write completion
        static let debounceInterval: TimeInterval = 0.5

        /// Maximum number of recent activity records to keep
        static let maxRecentActivityCount = 20
    }

    enum Session {
        /// Minimum valid session number
        static let minSession = 1

        /// Maximum valid session number
        static let maxSession = 30

        /// Default keywords used to detect session numbers in filenames
        static let defaultKeywords = ["S", "Session", "Lecture", "Week", "Class"]

        /// Default template for session destination folders
        static let defaultFolderTemplate = "Session {n}"
    }

    enum AutoDetect {
        /// Maximum number of files scanned per course folder
        static let maxFilesPerFolder = 200
    }
}
