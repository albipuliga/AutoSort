import SwiftUI

/// Settings tab for managing course mappings
struct CourseMappingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Course Mappings")
                        .font(.headline)
                    Text("Map course codes to destination folder names")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.isAutoDetecting {
                    ProgressView()
                        .scaleEffect(0.75)
                        .padding(.trailing, 4)
                }

                Button(action: {
                    viewModel.runAutoDetect()
                }) {
                    Label("Auto-detect", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.isAutoDetecting)

                Button(action: {
                    viewModel.isShowingAddMapping = true
                }) {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            // Mappings List
            if viewModel.courseMappings.isEmpty {
                emptyState
            } else {
                mappingsList
            }
        }
        .sheet(isPresented: $viewModel.isShowingAddMapping) {
            AddMappingSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.editingMapping) { mapping in
            EditMappingSheet(viewModel: viewModel, mapping: mapping)
        }
        .sheet(isPresented: $viewModel.isShowingAutoDetectSheet) {
            AutoDetectMappingsSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Auto-detect course mappings?",
            isPresented: $viewModel.showAutoDetectPrompt,
            titleVisibility: .visible
        ) {
            Button("Scan now") {
                viewModel.runAutoDetect()
            }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Scan your base directory to suggest course mappings.")
        }
        .alert(
            "Auto-detect",
            isPresented: Binding(
                get: { viewModel.autoDetectError != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.autoDetectError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.autoDetectError ?? "")
        }
        .onAppear {
            viewModel.maybePromptForAutoDetect()
        }
        .onChange(of: viewModel.isShowingAutoDetectSheet) { isShowing in
            if !isShowing {
                viewModel.resetAutoDetectState()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Course Mappings")
                .font(.headline)
            Text("Add a mapping to start sorting files automatically")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Button("Auto-detect") {
                    viewModel.runAutoDetect()
                }
                Button("Add Mapping") {
                    viewModel.isShowingAddMapping = true
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mappingsList: some View {
        List {
            ForEach(viewModel.courseMappings) { mapping in
                MappingRow(
                    mapping: mapping,
                    onToggle: { viewModel.toggleMapping(mapping) },
                    onEdit: { viewModel.editingMapping = mapping },
                    onDelete: { viewModel.deleteMapping(mapping) }
                )
            }
            .onDelete(perform: viewModel.deleteMappings)
        }
    }
}

// MARK: - Mapping Row

struct MappingRow: View {
    let mapping: CourseMapping
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { mapping.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(mapping.courseCode)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text(mapping.folderName)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .opacity(mapping.isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Add Mapping Sheet

struct AddMappingSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Course Mapping")
                .font(.headline)

            Form {
                TextField("Course Code", text: $viewModel.newCourseCode)
                    .textFieldStyle(.roundedBorder)
                    .textCase(.uppercase)

                TextField("Folder Name", text: $viewModel.newFolderName)
                    .textFieldStyle(.roundedBorder)

                if let error = viewModel.validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    viewModel.resetNewMappingFields()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    viewModel.addMapping()
                    if viewModel.validationError == nil {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newCourseCode.isEmpty || viewModel.newFolderName.isEmpty)
            }
        }
        .padding()
        .frame(width: 350, height: 220)
    }
}

// MARK: - Edit Mapping Sheet

struct EditMappingSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    let mapping: CourseMapping

    @State private var courseCode: String
    @State private var folderName: String
    @State private var isEnabled: Bool
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel, mapping: CourseMapping) {
        self.viewModel = viewModel
        self.mapping = mapping
        _courseCode = State(initialValue: mapping.courseCode)
        _folderName = State(initialValue: mapping.folderName)
        _isEnabled = State(initialValue: mapping.isEnabled)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Course Mapping")
                .font(.headline)

            Form {
                TextField("Course Code", text: $courseCode)
                    .textFieldStyle(.roundedBorder)
                    .textCase(.uppercase)

                TextField("Folder Name", text: $folderName)
                    .textFieldStyle(.roundedBorder)

                Toggle("Enabled", isOn: $isEnabled)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    var updated = mapping
                    updated.courseCode = courseCode.uppercased()
                    updated.folderName = folderName
                    updated.isEnabled = isEnabled
                    viewModel.updateMapping(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(courseCode.isEmpty || folderName.isEmpty)
            }
        }
        .padding()
        .frame(width: 350, height: 250)
    }
}

#Preview {
    CourseMappingsView(viewModel: SettingsViewModel())
        .frame(width: 500, height: 400)
}
