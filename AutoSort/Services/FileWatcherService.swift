import Foundation
import Combine

/// Protocol for receiving file watcher events
protocol FileWatcherDelegate: AnyObject {
    func fileWatcher(_ watcher: FileWatcherService, didDetectNewFile url: URL)
}

/// Monitors a directory for new files using DispatchSource
final class FileWatcherService {
    weak var delegate: FileWatcherDelegate?

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var knownFiles: Set<String> = []
    private var pendingFiles: [String: DispatchWorkItem] = [:]
    private let watchQueue = DispatchQueue(label: "com.autosort.filewatcher", qos: .utility)
    private let debounceInterval: TimeInterval

    private(set) var watchedDirectory: URL?
    private(set) var isWatching: Bool = false

    init(debounceInterval: TimeInterval = Constants.FileWatcher.debounceInterval) {
        self.debounceInterval = debounceInterval
    }

    deinit {
        stopWatching()
    }

    // MARK: - Public Methods

    /// Starts watching the specified directory for new files
    func startWatching(directory: URL) {
        stopWatching()

        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        watchedDirectory = directory

        // Initialize known files
        knownFiles = getCurrentFiles(in: directory)

        // Open file descriptor for the directory
        fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return
        }

        // Create dispatch source for file system events
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .link, .rename],
            queue: watchQueue
        )

        source?.setEventHandler { [weak self] in
            self?.handleDirectoryChange()
        }

        source?.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source?.resume()
        isWatching = true
    }

    /// Stops watching the current directory
    func stopWatching() {
        // Cancel any pending debounce work items
        for (_, workItem) in pendingFiles {
            workItem.cancel()
        }
        pendingFiles.removeAll()

        source?.cancel()
        source = nil
        isWatching = false
        watchedDirectory = nil
        knownFiles.removeAll()
    }

    /// Refreshes the known files list (useful after settings change)
    func refreshKnownFiles() {
        guard let directory = watchedDirectory else { return }
        knownFiles = getCurrentFiles(in: directory)
    }

    // MARK: - Private Methods

    private func handleDirectoryChange() {
        guard let directory = watchedDirectory else { return }

        let currentFiles = getCurrentFiles(in: directory)
        let newFiles = currentFiles.subtracting(knownFiles)

        for filename in newFiles {
            scheduleFileProcessing(filename: filename, in: directory)
        }

        knownFiles = currentFiles
    }

    private func getCurrentFiles(in directory: URL) -> Set<String> {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        return Set(contents.compactMap { url -> String? in
            // Only include regular files (not directories)
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else {
                return nil
            }
            return url.lastPathComponent
        })
    }

    /// Schedules file processing with debouncing to ensure file write is complete
    private func scheduleFileProcessing(filename: String, in directory: URL) {
        // Cancel any existing pending work for this file
        pendingFiles[filename]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let fileURL = directory.appendingPathComponent(filename)

            // Verify file still exists and is accessible
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  self.isFileReady(at: fileURL) else {
                return
            }

            self.pendingFiles.removeValue(forKey: filename)

            DispatchQueue.main.async {
                self.delegate?.fileWatcher(self, didDetectNewFile: fileURL)
            }
        }

        pendingFiles[filename] = workItem
        watchQueue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    /// Checks if a file is ready (not being written to)
    private func isFileReady(at url: URL) -> Bool {
        // Try to open file for reading to verify it's not locked
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        try? handle.close()
        return true
    }
}
