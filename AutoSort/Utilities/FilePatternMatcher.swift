import Foundation

/// Result of pattern matching on a filename
struct PatternMatchResult {
    let courseCode: String
    let sessionNumber: Int
    let courseMapping: CourseMapping
}

/// Handles pattern matching for course codes and session numbers in filenames
final class FilePatternMatcher {
    private let compiledCourseMatchers: [(mapping: CourseMapping, regex: NSRegularExpression)]
    private let sessionRegex: NSRegularExpression?

    init(courseMappings: [CourseMapping], sessionKeywords: [String]) {
        let enabledMappings = courseMappings.filter { $0.isEnabled }
        self.compiledCourseMatchers = enabledMappings.compactMap { mapping in
            let pattern = Self.buildCourseCodePattern(mapping.courseCode)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return nil
            }
            return (mapping: mapping, regex: regex)
        }
        let normalizedKeywords = Self.normalizeSessionKeywords(sessionKeywords)
        let keywords = normalizedKeywords.isEmpty ? Constants.Session.defaultKeywords : normalizedKeywords
        self.sessionRegex = Self.buildSessionRegex(from: keywords)
    }

    /// Attempts to match a filename against course codes and extract session number
    /// - Parameter filename: The filename to analyze
    /// - Returns: A PatternMatchResult if both course code and valid session number are found
    func match(filename: String) -> PatternMatchResult? {
        let uppercasedFilename = filename.uppercased()

        // Find matching course code
        guard let matchedMapping = findCourseCode(in: uppercasedFilename) else {
            return nil
        }

        // Extract session number
        guard let sessionNumber = extractSessionNumber(from: filename),
              isValidSessionNumber(sessionNumber) else {
            return nil
        }

        return PatternMatchResult(
            courseCode: matchedMapping.courseCode,
            sessionNumber: sessionNumber,
            courseMapping: matchedMapping
        )
    }

    /// Finds the first matching course code in the filename
    private func findCourseCode(in uppercasedFilename: String) -> CourseMapping? {
        let filenameRange = NSRange(uppercasedFilename.startIndex..., in: uppercasedFilename)
        for matcher in compiledCourseMatchers {
            if matcher.regex.firstMatch(
                in: uppercasedFilename,
                options: [],
                range: filenameRange
            ) != nil {
                return matcher.mapping
            }
        }
        return nil
    }

    /// Builds a regex pattern for a course code with word boundaries
    private static func buildCourseCodePattern(_ courseCode: String) -> String {
        // Escape any special regex characters in the course code
        let escaped = NSRegularExpression.escapedPattern(for: courseCode)
        // Match course code with word boundaries or common delimiters
        return #"(?:^|[_\-\s.])"# + escaped + #"(?:[_\-\s.]|$)"#
    }

    /// Extracts session number from filename using regex
    private func extractSessionNumber(from filename: String) -> Int? {
        guard let regex = sessionRegex else {
            return nil
        }

        let range = NSRange(filename.startIndex..., in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range),
              match.numberOfRanges >= 2,
              let numberRange = Range(match.range(at: 1), in: filename) else {
            return nil
        }

        return Int(filename[numberRange])
    }

    /// Validates that session number is within valid range (1-30)
    private func isValidSessionNumber(_ number: Int) -> Bool {
        number >= Constants.Session.minSession && number <= Constants.Session.maxSession
    }
}

// MARK: - Convenience Extensions

extension FilePatternMatcher {
    /// Creates a matcher from current settings
    static func fromCurrentSettings() -> FilePatternMatcher {
        FilePatternMatcher(
            courseMappings: SettingsService.shared.settings.courseMappings,
            sessionKeywords: SettingsService.shared.settings.sessionKeywords
        )
    }
}

// MARK: - Session Keyword Helpers

extension FilePatternMatcher {
    private static func normalizeSessionKeywords(_ keywords: [String]) -> [String] {
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

    /// Builds a regex to match any keyword followed by a 1-2 digit session number.
    /// Negative lookbehind prevents matching letters before the keyword.
    private static func buildSessionRegex(from keywords: [String]) -> NSRegularExpression? {
        let sorted = keywords.sorted { $0.count > $1.count }
        let escaped = sorted.map { NSRegularExpression.escapedPattern(for: $0) }
        let keywordPattern = "(?:" + escaped.joined(separator: "|") + ")"
        let delimiterPattern = #"(?:[\s_\-\.]*)"#
        let pattern = #"(?<![A-Za-z])"# + keywordPattern + delimiterPattern + #"(\d{1,2})(?!\d)"#
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }
}
