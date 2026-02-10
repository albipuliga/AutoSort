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
    case invalidDestinationComponent
    case destinationOutsideBaseDirectory
    case unsafeDestinationSymlink
    case moveFailed(Error)
    case folderCreationFailed(Error)
    case noRecentActivity
    case sourcePathMissing
    case undoSourceExists
    case undoDestinationMissing
    case undoPathOutsideAllowedRoots
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
        case .invalidDestinationComponent:
            return "Destination folder contains unsupported path characters"
        case .destinationOutsideBaseDirectory:
            return "Destination path is outside the selected base directory"
        case .unsafeDestinationSymlink:
            return "Destination path uses an unsafe symbolic link"
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
        case .undoPathOutsideAllowedRoots:
            return "Undo is only allowed for files inside configured folders"
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
        guard settingsService.settings.canWatch,
              let watchedFolder = settingsService.watchedFolderURL else {
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
        
        let matcher = FilePatternMatcher.fromCurrentSettings()

        guard let match = matcher.match(filename: filename) else {
            return .noMatch
        }

        do {
            let record = try sortFile(at: url, with: match)
            settingsService.addRecentActivity(record)

            if settingsService.settings.showNotifications {
                notificationService.sendFileSortedNotification(record: record)
            }

            return .success(record)
        } catch FileSorterError.duplicateSkipped {
            return .skippedDuplicate
        } catch {
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
        if settings.isWatchingEnabled,
           settings.canWatch,
           let watchedFolder = settingsService.watchedFolderURL {
            if fileWatcher.watchedDirectory?.path != watchedFolder.path {
                fileWatcher.startWatching(directory: watchedFolder)
            }
            isActive = true
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
        let courseFolderName = try validatedPathComponent(match.courseMapping.folderName)
        let sessionName = sessionFolderName(for: match.sessionNumber)
        let sessionFolderName = try validatedPathComponent(sessionName)

        let courseFolderURL = baseDirectory
            .appendingPathComponent(courseFolderName)

        let sessionFolderURL = courseFolderURL
            .appendingPathComponent(sessionFolderName)

        let courseFolderExisted = fileManager.fileExists(atPath: courseFolderURL.path)
        let sessionFolderExisted = fileManager.fileExists(atPath: sessionFolderURL.path)

        try ensureSafeDirectoryTarget(courseFolderURL, under: baseDirectory)
        try ensureSafeDirectoryTarget(sessionFolderURL, under: baseDirectory)

        let destinationURL = sessionFolderURL
            .appendingPathComponent(sourceURL.lastPathComponent)

        guard isURL(destinationURL, within: baseDirectory) else {
            throw FileSorterError.destinationOutsideBaseDirectory
        }

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
            try ensureSafeDirectoryTarget(sessionFolderURL, under: baseDirectory)
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

        guard isURL(finalDestinationURL, within: baseDirectory) else {
            throw FileSorterError.destinationOutsideBaseDirectory
        }

        // Move the file
        do {
            try fileManager.moveItem(at: sourceURL, to: finalDestinationURL)
        } catch {
            throw FileSorterError.moveFailed(error)
        }

        // Create and return the record
        var createdDestinationFolderPaths: [String] = []
        if !courseFolderExisted {
            createdDestinationFolderPaths.append(courseFolderURL.path)
        }
        if !sessionFolderExisted {
            createdDestinationFolderPaths.append(sessionFolderURL.path)
        }

        return SortedFileRecord(
            filename: sourceURL.lastPathComponent,
            courseCode: match.courseCode,
            sessionNumber: match.sessionNumber,
            sourcePath: sourcePathForUndo(from: sourceURL),
            destinationPath: finalDestinationURL.path,
            createdDestinationFolderPaths: createdDestinationFolderPaths.isEmpty ? nil : createdDestinationFolderPaths
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
        
        guard let baseDirectory = settingsService.baseDirectoryURL,
              isURL(destinationURL, within: baseDirectory),
              isUndoSourceAllowed(sourceURL) else {
            throw FileSorterError.undoPathOutsideAllowedRoots
        }

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

        cleanupCreatedDestinationFolders(for: record)
        settingsService.removeRecentActivity(record)
        return record
    }

    private func cleanupCreatedDestinationFolders(for record: SortedFileRecord) {
        guard let baseDirectory = settingsService.baseDirectoryURL else {
            return
        }

        let fileManager = FileManager.default
        let foldersToClean = (record.createdDestinationFolderPaths ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { isURL($0, within: baseDirectory) }
            .sorted { $0.pathComponents.count > $1.pathComponents.count }

        for folderURL in foldersToClean {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let contents = (try? fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: []
            )) ?? []

            if contents.isEmpty {
                try? fileManager.removeItem(at: folderURL)
            }
        }
    }

    private func sourcePathForUndo(from sourceURL: URL) -> String? {
        guard isUndoSourceAllowed(sourceURL) else {
            return nil
        }
        return sourceURL.path
    }

    private func isUndoSourceAllowed(_ sourceURL: URL) -> Bool {
        let allowedRoots = [
            settingsService.watchedFolderURL,
            settingsService.baseDirectoryURL
        ].compactMap { $0 }

        return allowedRoots.contains { isURL(sourceURL, within: $0) }
    }

    private func validatedPathComponent(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let containsPathSeparator = trimmed.contains("/") || trimmed.contains(":")
        let isUnsafeComponent = trimmed.isEmpty || trimmed == "." || trimmed == ".."

        if containsPathSeparator || isUnsafeComponent || trimmed.contains("\u{0}") {
            throw FileSorterError.invalidDestinationComponent
        }

        return trimmed
    }

    private func ensureSafeDirectoryTarget(_ directoryURL: URL, under baseDirectory: URL) throws {
        guard isURL(directoryURL, within: baseDirectory) else {
            throw FileSorterError.destinationOutsideBaseDirectory
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) else {
            return
        }

        guard isDirectory.boolValue else {
            throw FileSorterError.invalidDestinationComponent
        }

        let values = try? directoryURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values?.isSymbolicLink == true {
            throw FileSorterError.unsafeDestinationSymlink
        }
    }

    private func isURL(_ candidate: URL, within parent: URL) -> Bool {
        let canonicalCandidate = candidate.standardizedFileURL.resolvingSymlinksInPath().path
        let canonicalParent = parent.standardizedFileURL.resolvingSymlinksInPath().path

        if canonicalCandidate == canonicalParent {
            return true
        }

        return canonicalCandidate.hasPrefix(canonicalParent + "/")
    }
}

// MARK: - FileWatcherDelegate

extension FileSorterService: FileWatcherDelegate {
    func fileWatcher(_ watcher: FileWatcherService, didDetectNewFile url: URL) {
        _ = processFile(at: url)
    }
}
