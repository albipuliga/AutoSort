import SwiftUI

/// Container view for settings with tabs
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            CourseMappingsView(viewModel: viewModel)
                .tabItem {
                    Label("Courses", systemImage: "folder")
                }
        }
        .frame(width: 500, height: 400)
    }
}

#Preview {
    SettingsView()
}
