import Foundation
import Combine
import SwiftUI

/// View model for the menu bar interface
@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published var isWatching: Bool = false
    @Published var isConfigured: Bool = false
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
                self.isWatching = settings.isWatchingEnabled && settings.isConfigured
                self.isConfigured = settings.isConfigured
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

    func revealInFinder(_ record: SortedFileRecord) {
        record.revealInFinder()
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
        if !isConfigured {
            return "Not Configured"
        }
        return isWatching ? "Watching" : "Paused"
    }

    var statusColor: Color {
        if !isConfigured {
            return .gray
        }
        return isWatching ? .green : .orange
    }
}
