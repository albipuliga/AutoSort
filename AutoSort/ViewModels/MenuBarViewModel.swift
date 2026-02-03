import Foundation
import Combine
import SwiftUI

/// View model for the menu bar interface
@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published var isWatching: Bool = false
    @Published var isReadyToSort: Bool = false
    @Published var canWatch: Bool = false
    @Published var recentActivity: [SortedFileRecord] = []
    @Published var watchedFolderName: String?

    private let settingsService: SettingsService
    private let fileSorterService: FileSorterService
    private var cancellables = Set<AnyCancellable>()

    init(
        settingsService: SettingsService = .shared,
        fileSorterService: FileSorterService
    ) {
        self.settingsService = settingsService
        self.fileSorterService = fileSorterService

        setupBindings()
    }

    private func setupBindings() {
        // Observe settings changes
        settingsService.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self = self else { return }
                self.isReadyToSort = settings.isReadyForSorting
                self.canWatch = settings.canWatch
                self.isWatching = settings.isWatchingEnabled && settings.canWatch
                self.watchedFolderName = self.settingsService.watchedFolderURL?.lastPathComponent
            }
            .store(in: &cancellables)

        // Observe recent activity
        settingsService.$recentActivity
            .receive(on: DispatchQueue.main)
            .assign(to: &$recentActivity)

        // Observe sorter service active state
        fileSorterService.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                guard let self = self else { return }
                self.isWatching = isActive
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func toggleWatching() {
        settingsService.toggleWatching()
        if settingsService.settings.isWatchingEnabled {
            fileSorterService.start()
        } else {
            fileSorterService.stop()
        }
    }

    func clearRecentActivity() {
        settingsService.clearRecentActivity()
    }

    func undoLastMove() {
        _ = fileSorterService.undoLastMove()
    }

    func revealInFinder(_ record: SortedFileRecord) {
        record.revealInFinder()
    }

    func handleDroppedFiles(_ urls: [URL]) {
        guard isReadyToSort else { return }

        let fileURLs = urls.filter { $0.isFileURL && !$0.hasDirectoryPath }
        guard !fileURLs.isEmpty else { return }

        let sorterService = fileSorterService

        Task.detached(priority: .userInitiated) {
            var shouldCloseMenu = false

            for url in fileURLs {
                let didStartAccess = url.startAccessingSecurityScopedResource()
                let result = sorterService.processFile(at: url)
                switch result {
                case .success, .skippedDuplicate:
                    shouldCloseMenu = true
                case .noMatch, .error:
                    break
                }
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            if shouldCloseMenu {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: Constants.UI.menuBarShouldClose,
                        object: nil
                    )
                }
            }
        }
    }

    func openSettings() {
        // Open settings window using the standard AppKit action
        // This works on both macOS 13 and 14+
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
    
    func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Computed Properties

    var statusText: String {
        if !isReadyToSort {
            return "Not Configured"
        }
        if canWatch {
            return isWatching ? "Watching" : "Paused"
        }
        return "Manual Ready"
    }

    var statusColor: Color {
        if !isReadyToSort {
            return .gray
        }
        if canWatch {
            return isWatching ? .green : .orange
        }
        return .accentColor
    }

    var canUndoLastMove: Bool {
        guard let record = recentActivity.first else {
            return false
        }
        return record.sourcePath != nil
    }
}
