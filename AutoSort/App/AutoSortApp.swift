import SwiftUI

@main
struct AutoSortApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var fileSorterService = FileSorterService()
    @StateObject private var menuBarViewModel: MenuBarViewModel

    init() {
        let sorterService = FileSorterService()
        _fileSorterService = StateObject(wrappedValue: sorterService)
        _menuBarViewModel = StateObject(wrappedValue: MenuBarViewModel(fileSorterService: sorterService))
    }

    var body: some Scene {
        // Menu Bar
        MenuBarExtra {
            MenuBarView(viewModel: menuBarViewModel)
                .frame(width: 280)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        // Settings Window
        Settings {
            SettingsView()
        }
    }

    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.badge.gearshape")
            if menuBarViewModel.isWatching {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
            }
        }
    }
}
