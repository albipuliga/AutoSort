import Foundation

struct AutoDetectSuggestion: Identifiable, Hashable {
    var id: UUID
    var folderName: String
    var suggestedCode: String
    var matchCount: Int
    var filesScanned: Int
    var existingMappingId: UUID?

    init(
        id: UUID = UUID(),
        folderName: String,
        suggestedCode: String,
        matchCount: Int,
        filesScanned: Int,
        existingMappingId: UUID? = nil
    ) {
        self.id = id
        self.folderName = folderName
        self.suggestedCode = suggestedCode.uppercased()
        self.matchCount = matchCount
        self.filesScanned = filesScanned
        self.existingMappingId = existingMappingId
    }
}
