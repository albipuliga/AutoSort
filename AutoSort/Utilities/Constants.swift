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

    enum FileWatcher {
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
    }
}
