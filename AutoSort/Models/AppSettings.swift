import Foundation

/// Contains all application settings, persisted via Codable
struct AppSettings: Codable {
    var watchedFolderPath: String?
    var watchedFolderBookmark: Data?
    var baseDirectoryPath: String?
    var baseDirectoryBookmark: Data?
    var courseMappings: [CourseMapping]
    var isWatchingEnabled: Bool
    var launchAtLogin: Bool
    var showNotifications: Bool

    init(
        watchedFolderPath: String? = nil,
        watchedFolderBookmark: Data? = nil,
        baseDirectoryPath: String? = nil,
        baseDirectoryBookmark: Data? = nil,
        courseMappings: [CourseMapping] = [],
        isWatchingEnabled: Bool = true,
        launchAtLogin: Bool = false,
        showNotifications: Bool = true
    ) {
        self.watchedFolderPath = watchedFolderPath
        self.watchedFolderBookmark = watchedFolderBookmark
        self.baseDirectoryPath = baseDirectoryPath
        self.baseDirectoryBookmark = baseDirectoryBookmark
        self.courseMappings = courseMappings
        self.isWatchingEnabled = isWatchingEnabled
        self.launchAtLogin = launchAtLogin
        self.showNotifications = showNotifications
    }

    /// Checks if the app is properly configured to start sorting
    var isConfigured: Bool {
        watchedFolderPath != nil &&
        baseDirectoryPath != nil &&
        !courseMappings.isEmpty &&
        courseMappings.contains { $0.isEnabled }
    }

    /// Returns enabled course mappings only
    var enabledMappings: [CourseMapping] {
        courseMappings.filter { $0.isEnabled }
    }

    static let `default` = AppSettings()
}
