import SwiftUI

/// Main menu bar dropdown content
struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status Section
            statusSection

            Divider()
                .padding(.vertical, 4)

            // Toggle Watching
            if viewModel.isConfigured {
                toggleButton
                Divider()
                    .padding(.vertical, 4)
            }

            // Recent Activity
            recentActivitySection

            Divider()
                .padding(.vertical, 4)

            // Settings & Quit
            bottomSection
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.statusColor)
                .frame(width: 8, height: 8)

            Text(viewModel.statusText)
                .font(.headline)

            Spacer()

            if let folderName = viewModel.watchedFolderName {
                Text(folderName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Toggle Button

    private var toggleButton: some View {
        Button(action: viewModel.toggleWatching) {
            HStack {
                Image(systemName: viewModel.isWatching ? "pause.circle" : "play.circle")
                Text(viewModel.isWatching ? "Pause Watching" : "Start Watching")
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent Activity")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !viewModel.recentActivity.isEmpty {
                    Button("Undo") {
                        viewModel.undoLastMove()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(viewModel.canUndoLastMove ? .accentColor : .secondary)
                    .disabled(!viewModel.canUndoLastMove)

                    Button("Clear") {
                        viewModel.clearRecentActivity()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)

            if viewModel.recentActivity.isEmpty {
                Text("No files sorted yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            } else {
                RecentActivityView(
                    records: Array(viewModel.recentActivity.prefix(5)),
                    onReveal: viewModel.revealInFinder
                )
            }
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            settingsButton

            Button(action: viewModel.quit) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit AutoSort")
                    Spacer()
                    Text("Command+Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .keyboardShortcut("q", modifiers: .command)
        }
    }
    
    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        } else {
            Button(action: viewModel.openSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

#Preview {
    MenuBarView(
        viewModel: MenuBarViewModel(
            fileSorterService: FileSorterService()
        )
    )
    .frame(width: 280)
}
