import Foundation

struct AutoDetectResult {
    let suggestions: [AutoDetectSuggestion]
    let skippedFolderCount: Int
    let errors: [String]
}

final class CourseAutoDetectService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan(
        baseDirectoryURL: URL,
        sessionKeywords: [String],
        shouldCancel: @escaping () -> Bool = { Task.isCancelled }
    ) -> AutoDetectResult {
        guard !shouldCancel() else {
            return AutoDetectResult(suggestions: [], skippedFolderCount: 0, errors: [])
        }

        let normalizedKeywords = normalizeSessionKeywords(sessionKeywords)
        let effectiveKeywords = normalizedKeywords.isEmpty ? Constants.Session.defaultKeywords : normalizedKeywords
        guard let regex = buildInferenceRegex(from: effectiveKeywords) else {
            return AutoDetectResult(
                suggestions: [],
                skippedFolderCount: 0,
                errors: ["Failed to build inference pattern."]
            )
        }

        var suggestions: [AutoDetectSuggestion] = []
        var skippedFolderCount = 0
        var errors: [String] = []

        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        let topLevelURLs: [URL]

        do {
            guard !shouldCancel() else {
                return AutoDetectResult(suggestions: [], skippedFolderCount: 0, errors: [])
            }
            topLevelURLs = try fileManager.contentsOfDirectory(
                at: baseDirectoryURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
        } catch {
            return AutoDetectResult(
                suggestions: [],
                skippedFolderCount: 0,
                errors: ["Failed to scan base directory: \(error.localizedDescription)"]
            )
        }

        for folderURL in topLevelURLs {
            if shouldCancel() {
                return AutoDetectResult(
                    suggestions: suggestions,
                    skippedFolderCount: skippedFolderCount,
                    errors: errors
                )
            }

            guard (try? folderURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }

            do {
                if shouldCancel() {
                    return AutoDetectResult(
                        suggestions: suggestions,
                        skippedFolderCount: skippedFolderCount,
                        errors: errors
                    )
                }
                let childURLs = try fileManager.contentsOfDirectory(
                    at: folderURL,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsHiddenFiles]
                )

                var counts: [String: Int] = [:]
                var filesScanned = 0
                var remainingSlots = Constants.AutoDetect.maxFilesPerFolder

                // Scan top-level files in the course folder.
                let topLevelFiles = childURLs.filter {
                    (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                }

                for fileURL in topLevelFiles {
                    if shouldCancel() {
                        return AutoDetectResult(
                            suggestions: suggestions,
                            skippedFolderCount: skippedFolderCount,
                            errors: errors
                        )
                    }
                    guard remainingSlots > 0 else { break }
                    let filename = fileURL.lastPathComponent
                    filesScanned += 1
                    remainingSlots -= 1
                    if let code = extractCourseCode(from: filename, using: regex) {
                        counts[code, default: 0] += 1
                    }
                }

                // Scan immediate child folders (session folders) and their files (no recursion).
                let childFolders = childURLs.filter {
                    (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                }

                for sessionFolderURL in childFolders {
                    if shouldCancel() {
                        return AutoDetectResult(
                            suggestions: suggestions,
                            skippedFolderCount: skippedFolderCount,
                            errors: errors
                        )
                    }
                    let folderName = sessionFolderURL.lastPathComponent
                    filesScanned += 1
                    if let code = extractCourseCode(from: folderName, using: regex) {
                        counts[code, default: 0] += 1
                    }

                    guard remainingSlots > 0 else { continue }

                    if shouldCancel() {
                        return AutoDetectResult(
                            suggestions: suggestions,
                            skippedFolderCount: skippedFolderCount,
                            errors: errors
                        )
                    }
                    let sessionContents = try fileManager.contentsOfDirectory(
                        at: sessionFolderURL,
                        includingPropertiesForKeys: resourceKeys,
                        options: [.skipsHiddenFiles]
                    )
                    let sessionFiles = sessionContents.filter {
                        (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                    }

                    for fileURL in sessionFiles {
                        if shouldCancel() {
                            return AutoDetectResult(
                                suggestions: suggestions,
                                skippedFolderCount: skippedFolderCount,
                                errors: errors
                            )
                        }
                        guard remainingSlots > 0 else { break }
                        let filename = fileURL.lastPathComponent
                        filesScanned += 1
                        remainingSlots -= 1
                        if let code = extractCourseCode(from: filename, using: regex) {
                            counts[code, default: 0] += 1
                        }
                    }
                }

                guard let bestMatch = selectBestCode(from: counts) else {
                    skippedFolderCount += 1
                    continue
                }

                let suggestion = AutoDetectSuggestion(
                    folderName: folderURL.lastPathComponent,
                    suggestedCode: bestMatch.code,
                    matchCount: bestMatch.count,
                    filesScanned: filesScanned
                )
                suggestions.append(suggestion)
            } catch {
                errors.append("Failed to scan \(folderURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return AutoDetectResult(
            suggestions: suggestions,
            skippedFolderCount: skippedFolderCount,
            errors: errors
        )
    }

    private func normalizeSessionKeywords(_ keywords: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for keyword in keywords {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            normalized.append(trimmed)
        }

        return normalized
    }

    private func buildInferenceRegex(from keywords: [String]) -> NSRegularExpression? {
        let sorted = keywords.sorted { $0.count > $1.count }
        let escaped = sorted.map { NSRegularExpression.escapedPattern(for: $0) }
        let keywordPattern = "(?:" + escaped.joined(separator: "|") + ")"
        let delimiterPattern = #"(?:[\s_\-\.]*)"#
        let pattern = #"(?:^|[^A-Za-z0-9])([A-Za-z0-9]+)"# +
            delimiterPattern + keywordPattern + delimiterPattern + #"(\d{1,2})(?!\d)"#

        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private func extractCourseCode(from filename: String, using regex: NSRegularExpression) -> String? {
        let range = NSRange(filename.startIndex..., in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range),
              match.numberOfRanges >= 2,
              let codeRange = Range(match.range(at: 1), in: filename) else {
            return nil
        }

        return String(filename[codeRange]).uppercased()
    }

    private func selectBestCode(from counts: [String: Int]) -> (code: String, count: Int)? {
        guard !counts.isEmpty else { return nil }

        let sorted = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            if lhs.key.count != rhs.key.count {
                return lhs.key.count > rhs.key.count
            }
            return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }

        guard let best = sorted.first else { return nil }
        return (code: best.key, count: best.value)
    }
}
