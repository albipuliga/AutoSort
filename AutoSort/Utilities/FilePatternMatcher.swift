import Foundation

/// Result of pattern matching on a filename
struct PatternMatchResult {
    let courseCode: String
    let sessionNumber: Int
    let courseMapping: CourseMapping
}

/// Handles pattern matching for course codes and session numbers in filenames
final class FilePatternMatcher {
    private let courseMappings: [CourseMapping]

    /// Session pattern: "S" followed by 1-2 digits, with boundary checking
    /// Negative lookbehind prevents matching letters before S (e.g., "ES1" in "NOTES1")
    /// Negative lookahead prevents matching more digits after
    private static let sessionPattern = #"(?<![A-Za-z])S(\d{1,2})(?!\d)"#

    init(courseMappings: [CourseMapping]) {
        self.courseMappings = courseMappings.filter { $0.isEnabled }
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
        for mapping in courseMappings {
            let pattern = buildCourseCodePattern(mapping.courseCode)
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(
                   in: uppercasedFilename,
                   options: [],
                   range: NSRange(uppercasedFilename.startIndex..., in: uppercasedFilename)
               ) != nil {
                return mapping
            }
        }
        return nil
    }

    /// Builds a regex pattern for a course code with word boundaries
    private func buildCourseCodePattern(_ courseCode: String) -> String {
        // Escape any special regex characters in the course code
        let escaped = NSRegularExpression.escapedPattern(for: courseCode)
        // Match course code with word boundaries or common delimiters
        return #"(?:^|[_\-\s.])"# + escaped + #"(?:[_\-\s.]|$)"#
    }

    /// Extracts session number from filename using regex
    private func extractSessionNumber(from filename: String) -> Int? {
        guard let regex = try? NSRegularExpression(
            pattern: Self.sessionPattern,
            options: .caseInsensitive
        ) else {
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
        FilePatternMatcher(courseMappings: SettingsService.shared.settings.courseMappings)
    }
}
