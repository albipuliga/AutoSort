import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Drag-and-drop target for manual sorting
struct DropZoneView: View {
    let isEnabled: Bool
    let onDrop: ([URL]) -> Void

    @State private var isTargeted = false
    @State private var wasTargeted = false
    @State private var didAcceptDrop = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)

            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 1, dash: [6]))

            HStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                Text(isEnabled ? "Drop a file to sort" : "Configure destination and mappings")
            }
            .font(.callout)
            .foregroundColor(textColor)
        }
        .frame(height: 72)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        .onChange(of: isTargeted) { newValue in
            if newValue {
                wasTargeted = true
            } else if wasTargeted && !didAcceptDrop {
                NotificationCenter.default.post(
                    name: Constants.UI.menuBarShouldClose,
                    object: nil
                )
                wasTargeted = false
            }
        }
        .opacity(isEnabled ? 1.0 : 0.6)
        .help(isEnabled ? "Drop files here to sort them" : "Set a destination folder and course mappings")
    }

    private var backgroundColor: Color {
        if isTargeted && isEnabled {
            return Color.accentColor.opacity(0.12)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if isTargeted && isEnabled {
            return .accentColor
        }
        return .secondary.opacity(0.6)
    }

    private var textColor: Color {
        isEnabled ? .primary : .secondary
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard isEnabled else { return false }

        let urlProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !urlProviders.isEmpty else { return false }

        didAcceptDrop = true
        let group = DispatchGroup()
        var urls: [URL] = []

        for provider in urlProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    if let url = extractURL(from: item), url.isFileURL {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            let uniqueURLs = Array(Set(urls)).filter { !$0.hasDirectoryPath }
            guard !uniqueURLs.isEmpty else {
                didAcceptDrop = false
                return
            }
            onDrop(uniqueURLs)
            didAcceptDrop = false
        }

        return true
    }

    private func extractURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let nsurl = item as? NSURL {
            return nsurl as URL
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }
}

#Preview {
    VStack(spacing: 12) {
        DropZoneView(isEnabled: true) { _ in }
        DropZoneView(isEnabled: false) { _ in }
    }
    .padding()
    .frame(width: 260)
}
