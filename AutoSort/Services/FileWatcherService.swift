import Foundation

/// Protocol for receiving file watcher events
protocol FileWatcherDelegate: AnyObject {
    func fileWatcher(_ watcher: FileWatcherService, didDetectNewFile url: URL)
}

/// Monitors a directory for new files using DispatchSource
final class FileWatcherService {
    weak var delegate: FileWatcherDelegate?

    private let watchQueue = DispatchQueue(label: "com.autosort.filewatcher", qos: .utility)
    private let watchQueueSpecificKey = DispatchSpecificKey<Void>()

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var knownFiles: Set<String> = []
    private var pendingFiles: [String: DispatchWorkItem] = [:]
    private var scanWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval
    private let eventWindowInterval: TimeInterval

    private var watchedDirectoryStorage: URL?
    private var isWatchingStorage: Bool = false

    var watchedDirectory: URL? {
        executeOnWatchQueueSync {
            watchedDirectoryStorage
        }
    }

    var isWatching: Bool {
        executeOnWatchQueueSync {
            isWatchingStorage
        }
    }

    init(
        debounceInterval: TimeInterval = Constants.FileWatcher.debounceInterval,
        eventWindowInterval: TimeInterval = Constants.FileWatcher.eventWindowInterval
    ) {
        self.debounceInterval = debounceInterval
        self.eventWindowInterval = eventWindowInterval
        watchQueue.setSpecific(key: watchQueueSpecificKey, value: ())
    }

    deinit {
        executeOnWatchQueueSync {
            stopWatchingOnQueue()
        }
    }

    // MARK: - Public Methods

    /// Starts watching the specified directory for new files
    func startWatching(directory: URL) {
        executeOnWatchQueue { [weak self] in
            self?.startWatchingOnQueue(directory: directory)
        }
    }

    /// Stops watching the current directory
    func stopWatching() {
        executeOnWatchQueue { [weak self] in
            self?.stopWatchingOnQueue()
        }
    }

    /// Refreshes the known files list (useful after settings change)
    func refreshKnownFiles() {
        executeOnWatchQueue { [weak self] in
            guard let self = self, let directory = self.watchedDirectoryStorage else { return }
            self.knownFiles = self.getCurrentFiles(in: directory)
        }
    }

    // MARK: - Private Methods

    private func executeOnWatchQueue(_ work: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: watchQueueSpecificKey) != nil {
            work()
        } else {
            watchQueue.async(execute: work)
        }
    }

    private func executeOnWatchQueueSync<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: watchQueueSpecificKey) != nil {
            return work()
        } else {
            return watchQueue.sync(execute: work)
        }
    }

    private func startWatchingOnQueue(directory: URL) {
        stopWatchingOnQueue()

        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        watchedDirectoryStorage = directory
        knownFiles = getCurrentFiles(in: directory)

        fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            watchedDirectoryStorage = nil
            knownFiles.removeAll()
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .link, .rename],
            queue: watchQueue
        )
        self.source = source

        source.setEventHandler { [weak self] in
            self?.scheduleDirectoryScan()
        }

        source.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source.resume()
        isWatchingStorage = true
    }

    private func stopWatchingOnQueue() {
        scanWorkItem?.cancel()
        scanWorkItem = nil

        for (_, workItem) in pendingFiles {
            workItem.cancel()
        }
        pendingFiles.removeAll()

        source?.cancel()
        source = nil

        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }

        isWatchingStorage = false
        watchedDirectoryStorage = nil
        knownFiles.removeAll()
    }

    private func scheduleDirectoryScan() {
        scanWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.handleDirectoryChange()
        }

        scanWorkItem = workItem
        watchQueue.asyncAfter(deadline: .now() + eventWindowInterval, execute: workItem)
    }

    private func handleDirectoryChange() {
        guard let directory = watchedDirectoryStorage else { return }
        scanWorkItem = nil

        let currentFiles = getCurrentFiles(in: directory)
        let newFiles = currentFiles.subtracting(knownFiles)

        knownFiles = currentFiles

        for filename in newFiles {
            scheduleFileProcessing(filename: filename, in: directory)
        }
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
