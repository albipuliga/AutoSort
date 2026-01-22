import Foundation

/// Represents a mapping between a course code and its destination folder name
struct CourseMapping: Identifiable, Codable, Hashable {
    var id: UUID
    var courseCode: String
    var folderName: String
    var isEnabled: Bool

    init(id: UUID = UUID(), courseCode: String, folderName: String, isEnabled: Bool = true) {
        self.id = id
        self.courseCode = courseCode.uppercased()
        self.folderName = folderName
        self.isEnabled = isEnabled
    }

    /// Validates that the course code is not empty and contains only alphanumeric characters
    var isValid: Bool {
        !courseCode.isEmpty &&
        !folderName.isEmpty &&
        courseCode.allSatisfy { $0.isLetter || $0.isNumber }
    }
}

extension CourseMapping {
    static let example = CourseMapping(
        courseCode: "BLK",
        folderName: "BLOCKCHAIN"
    )

    static let examples: [CourseMapping] = [
        CourseMapping(courseCode: "BLK", folderName: "BLOCKCHAIN"),
        CourseMapping(courseCode: "ML", folderName: "MACHINE_LEARNING"),
        CourseMapping(courseCode: "CS101", folderName: "INTRO_TO_CS")
    ]
}
