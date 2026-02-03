import Foundation

/// Contains all application settings, persisted via Codable
struct AppSettings: Codable {
    var watchedFolderPath: String?
    var watchedFolderBookmark: Data?
    var baseDirectoryPath: String?
    var baseDirectoryBookmark: Data?
    var courseMappings: [CourseMapping]
    var sessionKeywords: [String]
    var sessionFolderTemplate: String
    var isWatchingEnabled: Bool
    var launchAtLogin: Bool
    var showNotifications: Bool
    var duplicateHandling: DuplicateHandlingOption

    init(
        watchedFolderPath: String? = nil,
        watchedFolderBookmark: Data? = nil,
        baseDirectoryPath: String? = nil,
        baseDirectoryBookmark: Data? = nil,
        courseMappings: [CourseMapping] = [],
        sessionKeywords: [String] = Constants.Session.defaultKeywords,
        sessionFolderTemplate: String = Constants.Session.defaultFolderTemplate,
        isWatchingEnabled: Bool = true,
        launchAtLogin: Bool = false,
        showNotifications: Bool = true,
        duplicateHandling: DuplicateHandlingOption = .rename
    ) {
        self.watchedFolderPath = watchedFolderPath
        self.watchedFolderBookmark = watchedFolderBookmark
        self.baseDirectoryPath = baseDirectoryPath
        self.baseDirectoryBookmark = baseDirectoryBookmark
        self.courseMappings = courseMappings
        self.sessionKeywords = sessionKeywords
        self.sessionFolderTemplate = sessionFolderTemplate
        self.isWatchingEnabled = isWatchingEnabled
        self.launchAtLogin = launchAtLogin
        self.showNotifications = showNotifications
        self.duplicateHandling = duplicateHandling
    }

    /// Checks if the app is properly configured to sort files (manual or watched)
    var isReadyForSorting: Bool {
        baseDirectoryPath != nil &&
        courseMappings.contains { $0.isEnabled }
    }

    /// Checks if the app has everything needed to watch a folder
    var canWatch: Bool {
        isReadyForSorting && watchedFolderPath != nil
    }

    /// Backwards-compatible configuration check
    var isConfigured: Bool {
        isReadyForSorting
    }

    /// Returns enabled course mappings only
    var enabledMappings: [CourseMapping] {
        courseMappings.filter { $0.isEnabled }
    }

    static let `default` = AppSettings()
}

extension AppSettings {
    enum CodingKeys: String, CodingKey {
        case watchedFolderPath
        case watchedFolderBookmark
        case baseDirectoryPath
        case baseDirectoryBookmark
        case courseMappings
        case sessionKeywords
        case sessionFolderTemplate
        case isWatchingEnabled
        case launchAtLogin
        case showNotifications
        case duplicateHandling
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        watchedFolderPath = try container.decodeIfPresent(String.self, forKey: .watchedFolderPath)
        watchedFolderBookmark = try container.decodeIfPresent(Data.self, forKey: .watchedFolderBookmark)
        baseDirectoryPath = try container.decodeIfPresent(String.self, forKey: .baseDirectoryPath)
        baseDirectoryBookmark = try container.decodeIfPresent(Data.self, forKey: .baseDirectoryBookmark)
        courseMappings = try container.decodeIfPresent([CourseMapping].self, forKey: .courseMappings) ?? []
        sessionKeywords = try container.decodeIfPresent([String].self, forKey: .sessionKeywords)
            ?? Constants.Session.defaultKeywords
        sessionFolderTemplate = try container.decodeIfPresent(String.self, forKey: .sessionFolderTemplate)
            ?? Constants.Session.defaultFolderTemplate
        isWatchingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isWatchingEnabled) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showNotifications = try container.decodeIfPresent(Bool.self, forKey: .showNotifications) ?? true
        duplicateHandling = try container.decodeIfPresent(DuplicateHandlingOption.self, forKey: .duplicateHandling) ?? .rename
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(watchedFolderPath, forKey: .watchedFolderPath)
        try container.encodeIfPresent(watchedFolderBookmark, forKey: .watchedFolderBookmark)
        try container.encodeIfPresent(baseDirectoryPath, forKey: .baseDirectoryPath)
        try container.encodeIfPresent(baseDirectoryBookmark, forKey: .baseDirectoryBookmark)
        try container.encode(courseMappings, forKey: .courseMappings)
        try container.encode(sessionKeywords, forKey: .sessionKeywords)
        try container.encode(sessionFolderTemplate, forKey: .sessionFolderTemplate)
        try container.encode(isWatchingEnabled, forKey: .isWatchingEnabled)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(showNotifications, forKey: .showNotifications)
        try container.encode(duplicateHandling, forKey: .duplicateHandling)
    }
}
