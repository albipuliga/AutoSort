import Foundation
import AppKit

/// Records a file that was sorted, for recent activity display
struct SortedFileRecord: Identifiable, Codable {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    let id: UUID
    let filename: String
    let courseCode: String
    let sessionNumber: Int
    let sourcePath: String?
    let destinationPath: String
    let createdDestinationFolderPaths: [String]?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        filename: String,
        courseCode: String,
        sessionNumber: Int,
        sourcePath: String? = nil,
        destinationPath: String,
        createdDestinationFolderPaths: [String]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.courseCode = courseCode
        self.sessionNumber = sessionNumber
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.createdDestinationFolderPaths = createdDestinationFolderPaths
        self.timestamp = timestamp
    }

    /// Human-readable destination description
    var destinationDescription: String {
        let sessionFolderName = URL(fileURLWithPath: destinationPath)
            .deletingLastPathComponent()
            .lastPathComponent
        return "\(courseCode) / \(sessionFolderName)"
    }

    /// Relative time string for display (e.g., "2 minutes ago")
    var relativeTimeString: String {
        Self.relativeFormatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Opens the destination folder in Finder
    func revealInFinder() {
        let url = URL(fileURLWithPath: destinationPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

extension SortedFileRecord {
    static let example = SortedFileRecord(
        filename: "BLK_S3_Slides.pdf",
        courseCode: "BLK",
        sessionNumber: 3,
        sourcePath: "/Users/example/Downloads/BLK_S3_Slides.pdf",
        destinationPath: "/Users/example/Courses/BLOCKCHAIN/Session 3/BLK_S3_Slides.pdf"
    )
}
