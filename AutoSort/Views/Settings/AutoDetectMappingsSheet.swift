import SwiftUI

struct AutoDetectMappingsSheet: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Auto-detect Course Mappings")
                    .font(.headline)
                Spacer()
            }

            if viewModel.autoDetectSuggestions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No Suggestions Found")
                        .font(.headline)
                    Text("Try adding more files or adjusting your session keywords.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($viewModel.autoDetectSuggestions) { $suggestion in
                        AutoDetectSuggestionRow(viewModel: viewModel, suggestion: $suggestion)
                    }
                }
            }

            if viewModel.autoDetectSkippedCount > 0 {
                Text("Skipped \(viewModel.autoDetectSkippedCount) folders with no matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let message = viewModel.autoDetectValidationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") {
                    viewModel.dismissAutoDetectSheet()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Selected") {
                    viewModel.applyAutoDetectSuggestions()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    viewModel.autoDetectSuggestions.isEmpty ||
                    viewModel.autoDetectValidationMessage != nil
                )
            }
        }
        .padding()
        .frame(width: 560, height: 420)
    }
}

struct AutoDetectSuggestionRow: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var suggestion: AutoDetectSuggestionState

    var body: some View {
        let normalizedCode = viewModel.normalizedCourseCode(suggestion.editedCode)
        let isValid = viewModel.isCourseCodeValid(normalizedCode)
        let duplicates = viewModel.autoDetectDuplicateCodes
        let isDuplicate = duplicates.contains(normalizedCode)
        let existingMapping = viewModel.existingMapping(for: normalizedCode)
        let hasConflict = existingMapping != nil

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(suggestion.suggestion.folderName)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                TextField("Course Code", text: $suggestion.editedCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .textCase(.uppercase)
                    .onChange(of: suggestion.editedCode) { newValue in
                        viewModel.updateAutoDetectCode(suggestion.id, newValue: newValue)
                    }
            }

            HStack(spacing: 8) {
                Text("Found in \(suggestion.suggestion.matchCount) of \(suggestion.suggestion.filesScanned) items")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if hasConflict, let existing = existingMapping {
                    Text("Conflicts with \(existing.folderName)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if isDuplicate {
                    Text("Duplicate code")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !isValid {
                    Text("Invalid code")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                Picker("Action", selection: $suggestion.action) {
                    if hasConflict {
                        Text("Keep existing (skip)").tag(AutoDetectAction.keepExisting)
                        Text("Replace existing").tag(AutoDetectAction.replaceExisting)
                        Text("Skip").tag(AutoDetectAction.skip)
                    } else {
                        Text("Add").tag(AutoDetectAction.add)
                        Text("Skip").tag(AutoDetectAction.skip)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AutoDetectMappingsSheet(viewModel: SettingsViewModel())
        .frame(width: 600, height: 420)
}
