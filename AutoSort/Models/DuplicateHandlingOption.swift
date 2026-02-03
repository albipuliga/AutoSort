import Foundation

enum DuplicateHandlingOption: String, Codable, CaseIterable, Identifiable {
    case rename
    case skip
    case replace
    case ask

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rename:
            return "Rename"
        case .skip:
            return "Skip"
        case .replace:
            return "Replace"
        case .ask:
            return "Ask"
        }
    }

    var description: String {
        switch self {
        case .rename:
            return "Keep both files by adding a number"
        case .skip:
            return "Leave the new file in the watch folder"
        case .replace:
            return "Overwrite the existing file"
        case .ask:
            return "Prompt every time a duplicate is found"
        }
    }
}
