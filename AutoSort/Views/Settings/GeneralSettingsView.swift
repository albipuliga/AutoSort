import SwiftUI

/// Settings tab for general configuration
struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var isSelectingWatchedFolder = false
    @State private var isSelectingBaseDirectory = false
    @FocusState private var isSessionKeywordsFocused: Bool
    @FocusState private var isSessionFolderTemplateFocused: Bool

    var body: some View {
        Form {
            Section {
                folderPicker(
                    title: "Watch Folder",
                    subtitle: "New files in this folder will be automatically sorted",
                    displayName: viewModel.watchedFolderDisplayName,
                    isSelecting: $isSelectingWatchedFolder,
                    onSelect: viewModel.setWatchedFolder
                )

                folderPicker(
                    title: "Destination Folder",
                    subtitle: "Course folders will be created here",
                    displayName: viewModel.baseDirectoryDisplayName,
                    isSelecting: $isSelectingBaseDirectory,
                    onSelect: viewModel.setBaseDirectory
                )
            } header: {
                Text("Folders")
            }

            Section {
                Toggle("Show notifications", isOn: Binding(
                    get: { viewModel.showNotifications },
                    set: { viewModel.setShowNotifications($0) }
                ))

                Toggle("Launch at login", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))

                Picker("Duplicates", selection: Binding(
                    get: { viewModel.duplicateHandling },
                    set: { viewModel.setDuplicateHandling($0) }
                )) {
                    ForEach(DuplicateHandlingOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Text(viewModel.duplicateHandling.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Behavior")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "Session keywords (e.g., S, Session, Lecture)",
                        text: Binding(
                            get: { viewModel.sessionKeywordsText },
                            set: { viewModel.setSessionKeywordsText($0) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($isSessionKeywordsFocused)
                    .onSubmit {
                        viewModel.commitSessionKeywords()
                    }
                    .onChange(of: isSessionKeywordsFocused) { focused in
                        if !focused {
                            viewModel.commitSessionKeywords()
                        }
                    }

                    Text(
                        "Used to detect session numbers in filenames (matches Week1 and Week 1). " +
                        "Separate keywords with commas; leave empty to use defaults. " +
                        "Does not affect destination folder names."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } header: {
                Text("Matching")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "Session folder name (e.g., Session {n} or Week {n})",
                        text: Binding(
                            get: { viewModel.sessionFolderTemplateText },
                            set: { viewModel.setSessionFolderTemplateText($0) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($isSessionFolderTemplateFocused)
                    .onSubmit {
                        viewModel.commitSessionFolderTemplate()
                    }
                    .onChange(of: isSessionFolderTemplateFocused) { focused in
                        if !focused {
                            viewModel.commitSessionFolderTemplate()
                        }
                    }

                    Text(
                        "Use {n} or {number} as a placeholder. If omitted, the number is appended. " +
                        "Independent from matching keywords."
                    )
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Destination")
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.headline)

                        if viewModel.hasValidConfiguration {
                            Label("Ready to sort files", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Configuration incomplete", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()
                }
            } header: {
                Text("Configuration Status")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func folderPicker(
        title: String,
        subtitle: String,
        displayName: String,
        isSelecting: Binding<Bool>,
        onSelect: @escaping (URL) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Choose...") {
                    isSelecting.wrappedValue = true
                }
            }

            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.secondary)
                Text(displayName)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(displayName == "Not Selected" ? .secondary : .primary)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .fileImporter(
            isPresented: isSelecting,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    onSelect(url)
                }
            case .failure(let error):
                _ = error
            }
        }
    }
}

#Preview {
    GeneralSettingsView(viewModel: SettingsViewModel())
        .frame(width: 500, height: 400)
}
