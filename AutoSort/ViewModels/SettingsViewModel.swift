import Foundation
import Combine
import SwiftUI

/// View model for the settings window
@MainActor
final class SettingsViewModel: ObservableObject {
    // General Settings
    @Published var watchedFolderPath: String?
    @Published var baseDirectoryPath: String?
    @Published var launchAtLogin: Bool = false
    @Published var showNotifications: Bool = true

    // Course Mappings
    @Published var courseMappings: [CourseMapping] = []

    // UI State
    @Published var isShowingAddMapping: Bool = false
    @Published var editingMapping: CourseMapping?
    @Published var newCourseCode: String = ""
    @Published var newFolderName: String = ""
    @Published var validationError: String?

    private let settingsService: SettingsService
    private var cancellables = Set<AnyCancellable>()

    init(settingsService: SettingsService = .shared) {
        self.settingsService = settingsService
        setupBindings()
    }

    private func setupBindings() {
        settingsService.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.watchedFolderPath = settings.watchedFolderPath
                self?.baseDirectoryPath = settings.baseDirectoryPath
                self?.launchAtLogin = settings.launchAtLogin
                self?.showNotifications = settings.showNotifications
                self?.courseMappings = settings.courseMappings
            }
            .store(in: &cancellables)
    }

    // MARK: - Folder Selection

    func setWatchedFolder(_ url: URL) {
        settingsService.setWatchedFolder(url)
    }

    func setBaseDirectory(_ url: URL) {
        settingsService.setBaseDirectory(url)
    }

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        settingsService.setLaunchAtLogin(enabled)
    }

    // MARK: - Notifications

    func setShowNotifications(_ show: Bool) {
        settingsService.setShowNotifications(show)
    }

    // MARK: - Course Mappings

    func addMapping() {
        guard validateNewMapping() else { return }

        let mapping = CourseMapping(
            courseCode: newCourseCode.trimmingCharacters(in: .whitespaces),
            folderName: newFolderName.trimmingCharacters(in: .whitespaces)
        )

        settingsService.addCourseMapping(mapping)
        resetNewMappingFields()
        isShowingAddMapping = false
    }

    func updateMapping(_ mapping: CourseMapping) {
        settingsService.updateCourseMapping(mapping)
        editingMapping = nil
    }

    func deleteMapping(_ mapping: CourseMapping) {
        settingsService.deleteCourseMapping(mapping)
    }

    func deleteMappings(at offsets: IndexSet) {
        for index in offsets {
            settingsService.deleteCourseMapping(courseMappings[index])
        }
    }

    func toggleMapping(_ mapping: CourseMapping) {
        settingsService.toggleCourseMapping(mapping)
    }

    // MARK: - Validation

    private func validateNewMapping() -> Bool {
        let trimmedCode = newCourseCode.trimmingCharacters(in: .whitespaces)
        let trimmedFolder = newFolderName.trimmingCharacters(in: .whitespaces)

        if trimmedCode.isEmpty {
            validationError = "Course code cannot be empty"
            return false
        }

        if trimmedFolder.isEmpty {
            validationError = "Folder name cannot be empty"
            return false
        }

        if !trimmedCode.allSatisfy({ $0.isLetter || $0.isNumber }) {
            validationError = "Course code can only contain letters and numbers"
            return false
        }

        if courseMappings.contains(where: { $0.courseCode.uppercased() == trimmedCode.uppercased() }) {
            validationError = "A mapping for this course code already exists"
            return false
        }

        validationError = nil
        return true
    }

    func resetNewMappingFields() {
        newCourseCode = ""
        newFolderName = ""
        validationError = nil
    }

    // MARK: - Computed Properties

    var watchedFolderDisplayName: String {
        guard let path = watchedFolderPath else { return "Not Selected" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var baseDirectoryDisplayName: String {
        guard let path = baseDirectoryPath else { return "Not Selected" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var hasValidConfiguration: Bool {
        watchedFolderPath != nil &&
        baseDirectoryPath != nil &&
        !courseMappings.isEmpty
    }
}
