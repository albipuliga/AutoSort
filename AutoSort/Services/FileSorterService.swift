import Foundation
import Combine
import AppKit

/// Result of a file sorting operation
enum SortingResult {
    case success(SortedFileRecord)
    case noMatch
    case skippedDuplicate
    case error(Error)
}

/// Errors that can occur during file sorting
enum FileSorterError: LocalizedError {
    case baseDirectoryNotSet
    case sourceFileNotFound
    case destinationExists
    case moveFailed(Error)
    case folderCreationFailed(Error)
    case noRecentActivity
    case sourcePathMissing
    case undoSourceExists
    case undoDestinationMissing
    case duplicateSkipped
    case removeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .baseDirectoryNotSet:
            return "Base directory is not configured"
        case .sourceFileNotFound:
            return "Source file no longer exists"
        case .destinationExists:
            return "A file with the same name already exists at the destination"
        case .moveFailed(let error):
            return "Failed to move file: \(error.localizedDescription)"
        case .folderCreationFailed(let error):
            return "Failed to create destination folder: \(error.localizedDescription)"
        case .noRecentActivity:
            return "No recent file move to undo"
        case .sourcePathMissing:
            return "Original file location is unknown"
        case .undoSourceExists:
            return "A file already exists at the original location"
        case .undoDestinationMissing:
            return "Moved file could not be found at the destination"
        case .duplicateSkipped:
            return "Duplicate file was skipped"
        case .removeFailed(let error):
            return "Failed to remove existing file: \(error.localizedDescription)"
        }
    }
}

/// Service that handles pattern matching and file moving
final class FileSorterService: ObservableObject {
    private let settingsService: SettingsService
    private let fileWatcher: FileWatcherService
    private let notificationService: NotificationService
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var isActive: Bool = false

    init(
        settingsService: SettingsService = .shared,
        fileWatcher: FileWatcherService = FileWatcherService(),
        notificationService: NotificationService = .shared
    ) {
        self.settingsService = settingsService
        self.fileWatcher = fileWatcher
        self.notificationService = notificationService

        fileWatcher.delegate = self

        // React to settings changes
        settingsService.$settings
            .sink { [weak self] settings in
                self?.handleSettingsChange(settings)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Starts the file sorting service
    func start() {
        guard let watchedFolder = settingsService.watchedFolderURL,
              settingsService.settings.isConfigured else {
            return
        }

        fileWatcher.startWatching(directory: watchedFolder)
        isActive = true
    }

    /// Stops the file sorting service
    func stop() {
        fileWatcher.stopWatching()
        isActive = false
    }

    /// Manually processes a file
    func processFile(at url: URL) -> SortingResult {
        let filename = url.lastPathComponent
        print("📁 Processing file: \(filename)")
        
        let matcher = FilePatternMatcher.fromCurrentSettings()

        guard let match = matcher.match(filename: filename) else {
            print("❌ No match found for: \(filename)")
            return .noMatch
        }

        print("✅ Match found - Course: \(match.courseCode), Session: \(match.sessionNumber)")

        do {
            let record = try sortFile(at: url, with: match)
            print("✅ File sorted successfully to: \(record.destinationPath)")
            settingsService.addRecentActivity(record)

            if settingsService.settings.showNotifications {
                notificationService.sendFileSortedNotification(record: record)
            }

            return .success(record)
        } catch FileSorterError.duplicateSkipped {
            print("⏭️ Duplicate file skipped: \(filename)")
            return .skippedDuplicate
        } catch {
            print("❌ Error sorting file: \(error.localizedDescription)")
            return .error(error)
        }
    }

    /// Undo the most recent file move, if possible
    func undoLastMove() -> Result<SortedFileRecord, Error> {
        let record = settingsService.recentActivity.first
        let wasActive = isActive

        if wasActive {
            stop()
        }

        defer {
            if wasActive {
                start()
            }
        }

        do {
            let revertedRecord = try revertMostRecentMove(record)

            if settingsService.settings.showNotifications {
                notificationService.sendUndoSuccessNotification(record: revertedRecord)
            }

            return .success(revertedRecord)
        } catch {
            if settingsService.settings.showNotifications {
                let filename = record?.filename ?? "file"
                notificationService.sendUndoErrorNotification(filename: filename, error: error.localizedDescription)
            }
            return .failure(error)
        }
    }

    // MARK: - Private Methods

    private func handleSettingsChange(_ settings: AppSettings) {
        if settings.isWatchingEnabled && settings.isConfigured {
            if let watchedFolder = settingsService.watchedFolderURL {
                if fileWatcher.watchedDirectory?.path != watchedFolder.path {
                    fileWatcher.startWatching(directory: watchedFolder)
                }
                isActive = true
            }
        } else {
            fileWatcher.stopWatching()
            isActive = false
        }
    }

    private func sortFile(at sourceURL: URL, with match: PatternMatchResult) throws -> SortedFileRecord {
        let fileManager = FileManager.default

        // Verify base directory
        guard let baseDirectory = settingsService.baseDirectoryURL else {
            throw FileSorterError.baseDirectoryNotSet
        }

        // Verify source file exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw FileSorterError.sourceFileNotFound
        }

        // Build destination path: {base}/{courseFolderName}/Session {n}/
        let courseFolderURL = baseDirectory
            .appendingPathComponent(match.courseMapping.folderName)

        let sessionFolderURL = courseFolderURL
            .appendingPathComponent(sessionFolderName(for: match.sessionNumber))

        let destinationURL = sessionFolderURL
            .appendingPathComponent(sourceURL.lastPathComponent)

        // Create session folder if needed
        if !fileManager.fileExists(atPath: sessionFolderURL.path) {
            do {
                try fileManager.createDirectory(
                    at: sessionFolderURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw FileSorterError.folderCreationFailed(error)
            }
        }

        var finalDestinationURL = destinationURL

        // Handle duplicates if destination file already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            let resolution = try resolveDuplicateResolution(
                for: sourceURL,
                destinationURL: destinationURL
            )

            switch resolution {
            case .skip:
                throw FileSorterError.duplicateSkipped
            case .replace:
                do {
                    try fileManager.removeItem(at: destinationURL)
                } catch {
                    throw FileSorterError.removeFailed(error)
                }
                finalDestinationURL = destinationURL
            case .rename:
                finalDestinationURL = uniqueDestinationURL(for: destinationURL)
            }
        }

        // Move the file
        do {
            try fileManager.moveItem(at: sourceURL, to: finalDestinationURL)
        } catch {
            throw FileSorterError.moveFailed(error)
        }

        // Create and return the record
        return SortedFileRecord(
            filename: sourceURL.lastPathComponent,
            courseCode: match.courseCode,
            sessionNumber: match.sessionNumber,
            sourcePath: sourceURL.path,
            destinationPath: finalDestinationURL.path
        )
    }

    private func sessionFolderName(for sessionNumber: Int) -> String {
        let rawTemplate = settingsService.settings.sessionFolderTemplate
        let trimmed = rawTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = trimmed.isEmpty ? Constants.Session.defaultFolderTemplate : trimmed
        let number = String(sessionNumber)

        if template.contains("{number}") || template.contains("{n}") {
            return template
                .replacingOccurrences(of: "{number}", with: number)
                .replacingOccurrences(of: "{n}", with: number)
        }

        return "\(template) \(number)"
    }

    private enum DuplicateResolution {
        case rename
        case skip
        case replace
    }

    private func resolveDuplicateResolution(
        for sourceURL: URL,
        destinationURL: URL
    ) throws -> DuplicateResolution {
        switch settingsService.settings.duplicateHandling {
        case .rename:
            return .rename
        case .skip:
            return .skip
        case .replace:
            return .replace
        case .ask:
            return promptForDuplicateResolution(
                filename: sourceURL.lastPathComponent,
                destinationURL: destinationURL
            )
        }
    }

    private func promptForDuplicateResolution(
        filename: String,
        destinationURL: URL
    ) -> DuplicateResolution {
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                promptForDuplicateResolution(filename: filename, destinationURL: destinationURL)
            }
        }

        let alert = NSAlert()
        alert.messageText = "Duplicate File"
        alert.informativeText = "\(filename) already exists in \(destinationURL.deletingLastPathComponent().lastPathComponent)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Skip")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            return .replace
        case .alertSecondButtonReturn:
            return .rename
        default:
            return .skip
        }
    }

    private func uniqueDestinationURL(for destinationURL: URL) -> URL {
        let fileManager = FileManager.default
        let folderURL = destinationURL.deletingLastPathComponent()
        let baseName = destinationURL.deletingPathExtension().lastPathComponent
        let fileExtension = destinationURL.pathExtension

        for index in 1...9999 {
            let candidateName = fileExtension.isEmpty
                ? "\(baseName) (\(index))"
                : "\(baseName) (\(index)).\(fileExtension)"
            let candidateURL = folderURL.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return destinationURL
    }
    private func revertMostRecentMove(_ record: SortedFileRecord?) throws -> SortedFileRecord {
        guard let record = record else {
            throw FileSorterError.noRecentActivity
        }

        guard let sourcePath = record.sourcePath else {
            throw FileSorterError.sourcePathMissing
        }

        let fileManager = FileManager.default
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destinationURL = URL(fileURLWithPath: record.destinationPath)

        guard fileManager.fileExists(atPath: destinationURL.path) else {
            throw FileSorterError.undoDestinationMissing
        }

        if fileManager.fileExists(atPath: sourceURL.path) {
            throw FileSorterError.undoSourceExists
        }

        let sourceFolderURL = sourceURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: sourceFolderURL.path) {
            do {
                try fileManager.createDirectory(
                    at: sourceFolderURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw FileSorterError.folderCreationFailed(error)
            }
        }

        do {
            try fileManager.moveItem(at: destinationURL, to: sourceURL)
        } catch {
            throw FileSorterError.moveFailed(error)
        }

        settingsService.removeRecentActivity(record)
        return record
    }
}

// MARK: - FileWatcherDelegate

extension FileSorterService: FileWatcherDelegate {
    func fileWatcher(_ watcher: FileWatcherService, didDetectNewFile url: URL) {
        _ = processFile(at: url)
    }
}
