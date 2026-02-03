import Foundation
import Combine
import ServiceManagement

/// Manages app settings persistence using UserDefaults and security-scoped bookmarks
final class SettingsService: ObservableObject {
    static let shared = SettingsService()

    @Published private(set) var settings: AppSettings {
        didSet {
            save()
        }
    }

    @Published private(set) var recentActivity: [SortedFileRecord] = []

    // Security-scoped URLs that are actively accessing resources
    private var watchedFolderSecurityURL: URL?
    private var baseDirectorySecurityURL: URL?

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        self.settings = Self.loadSettings()
        self.recentActivity = Self.loadRecentActivity()
        restoreSecurityScopedBookmarks()
    }
    
    deinit {
        // Stop accessing security-scoped resources
        watchedFolderSecurityURL?.stopAccessingSecurityScopedResource()
        baseDirectorySecurityURL?.stopAccessingSecurityScopedResource()
    }

    // MARK: - Settings Persistence

    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: Constants.UserDefaultsKeys.appSettings),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    private func save() {
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: Constants.UserDefaultsKeys.appSettings)
    }

    // MARK: - Recent Activity

    private static func loadRecentActivity() -> [SortedFileRecord] {
        guard let data = UserDefaults.standard.data(forKey: Constants.UserDefaultsKeys.recentActivity),
              let records = try? JSONDecoder().decode([SortedFileRecord].self, from: data) else {
            return []
        }
        return records
    }

    func addRecentActivity(_ record: SortedFileRecord) {
        recentActivity.insert(record, at: 0)
        if recentActivity.count > Constants.FileWatcher.maxRecentActivityCount {
            recentActivity = Array(recentActivity.prefix(Constants.FileWatcher.maxRecentActivityCount))
        }
        saveRecentActivity()
    }

    func clearRecentActivity() {
        recentActivity.removeAll()
        saveRecentActivity()
    }

    func removeRecentActivity(_ record: SortedFileRecord) {
        recentActivity.removeAll { $0.id == record.id }
        saveRecentActivity()
    }

    private func saveRecentActivity() {
        guard let data = try? encoder.encode(recentActivity) else { return }
        defaults.set(data, forKey: Constants.UserDefaultsKeys.recentActivity)
    }

    // MARK: - Folder Selection with Security-Scoped Bookmarks

    func setWatchedFolder(_ url: URL) {
        print("📂 Setting watched folder: \(url.path)")

        // Stop accessing the old security-scoped resource
        watchedFolderSecurityURL?.stopAccessingSecurityScopedResource()
        watchedFolderSecurityURL = nil

        // IMPORTANT: Start accessing security-scoped resource BEFORE creating bookmark
        // URLs from fileImporter require this to create bookmarks from them
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Failed to start accessing security-scoped resource for watched folder")
            settings.watchedFolderPath = url.path
            return
        }

        do {
            let bookmark = try createSecurityScopedBookmark(for: url)
            settings.watchedFolderPath = url.path
            settings.watchedFolderBookmark = bookmark
            watchedFolderSecurityURL = url
            print("✅ Security-scoped access granted and bookmark created for watched folder")
        } catch {
            print("❌ Failed to create bookmark for watched folder: \(error)")
            // Keep access since we successfully started it
            watchedFolderSecurityURL = url
            settings.watchedFolderPath = url.path
        }
    }

    func setBaseDirectory(_ url: URL) {
        print("📂 Setting base directory: \(url.path)")

        // Stop accessing the old security-scoped resource
        baseDirectorySecurityURL?.stopAccessingSecurityScopedResource()
        baseDirectorySecurityURL = nil

        // IMPORTANT: Start accessing security-scoped resource BEFORE creating bookmark
        // URLs from fileImporter require this to create bookmarks from them
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Failed to start accessing security-scoped resource for base directory")
            settings.baseDirectoryPath = url.path
            return
        }

        do {
            let bookmark = try createSecurityScopedBookmark(for: url)
            settings.baseDirectoryPath = url.path
            settings.baseDirectoryBookmark = bookmark
            baseDirectorySecurityURL = url
            print("✅ Security-scoped access granted and bookmark created for base directory")
        } catch {
            print("❌ Failed to create bookmark for base directory: \(error)")
            // Keep access since we successfully started it
            baseDirectorySecurityURL = url
            settings.baseDirectoryPath = url.path
        }
    }

    private func createSecurityScopedBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func restoreSecurityScopedBookmarks() {
        print("🔄 Restoring security-scoped bookmarks...")
        
        if let bookmarkData = settings.watchedFolderBookmark {
            if let url = restoreBookmark(bookmarkData) {
                watchedFolderSecurityURL = url
                print("✅ Restored watched folder: \(url.path)")
            } else {
                print("❌ Failed to restore watched folder bookmark")
            }
        }
        
        if let bookmarkData = settings.baseDirectoryBookmark {
            if let url = restoreBookmark(bookmarkData) {
                baseDirectorySecurityURL = url
                print("✅ Restored base directory: \(url.path)")
            } else {
                print("❌ Failed to restore base directory bookmark")
            }
        }
    }

    @discardableResult
    private func restoreBookmark(_ data: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                print("⚠️ Bookmark is stale for: \(url.path)")
            }
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Failed to start accessing security-scoped resource: \(url.path)")
                return nil
            }
            return url
        } catch {
            print("❌ Failed to restore bookmark: \(error)")
            return nil
        }
    }
    
    // MARK: - Security-Scoped URL Access
    
    /// Returns the watched folder URL with active security-scoped access
    var watchedFolderURL: URL? {
        return watchedFolderSecurityURL
    }
    
    /// Returns the base directory URL with active security-scoped access
    var baseDirectoryURL: URL? {
        return baseDirectorySecurityURL
    }

    // MARK: - Course Mappings

    func addCourseMapping(_ mapping: CourseMapping) {
        guard !settings.courseMappings.contains(where: {
            $0.courseCode.uppercased() == mapping.courseCode.uppercased()
        }) else {
            return
        }
        settings.courseMappings.append(mapping)
    }

    func updateCourseMapping(_ mapping: CourseMapping) {
        guard let index = settings.courseMappings.firstIndex(where: { $0.id == mapping.id }) else {
            return
        }
        settings.courseMappings[index] = mapping
    }

    func deleteCourseMapping(_ mapping: CourseMapping) {
        settings.courseMappings.removeAll { $0.id == mapping.id }
    }

    func toggleCourseMapping(_ mapping: CourseMapping) {
        guard let index = settings.courseMappings.firstIndex(where: { $0.id == mapping.id }) else {
            return
        }
        settings.courseMappings[index].isEnabled.toggle()
    }

    // MARK: - Session Keywords

    func setSessionKeywords(_ keywords: [String]) {
        let normalized = normalizeSessionKeywords(keywords)
        settings.sessionKeywords = normalized.isEmpty ? Constants.Session.defaultKeywords : normalized
    }

    func setSessionFolderTemplate(_ template: String) {
        let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.sessionFolderTemplate = trimmed.isEmpty ? Constants.Session.defaultFolderTemplate : trimmed
    }

    private func normalizeSessionKeywords(_ keywords: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for keyword in keywords {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            normalized.append(trimmed)
        }

        return normalized
    }

    // MARK: - Watching State

    func setWatchingEnabled(_ enabled: Bool) {
        settings.isWatchingEnabled = enabled
    }

    func toggleWatching() {
        settings.isWatchingEnabled.toggle()
    }

    // MARK: - Notifications

    func setShowNotifications(_ show: Bool) {
        settings.showNotifications = show
    }

    // MARK: - Duplicate Handling

    func setDuplicateHandling(_ option: DuplicateHandlingOption) {
        settings.duplicateHandling = option
    }

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        updateLaunchAtLoginState(enabled)
    }

    private func updateLaunchAtLoginState(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}
