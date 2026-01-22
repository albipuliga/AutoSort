import SwiftUI

/// Displays recent file sorting activity
struct RecentActivityView: View {
    let records: [SortedFileRecord]
    let onReveal: (SortedFileRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(records) { record in
                RecentActivityRow(record: record, onReveal: onReveal)
            }
        }
    }
}

/// A single row in the recent activity list
struct RecentActivityRow: View {
    let record: SortedFileRecord
    let onReveal: (SortedFileRecord) -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: { onReveal(record) }) {
            HStack(spacing: 8) {
                Image(systemName: fileIcon)
                    .foregroundColor(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.filename)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(record.destinationDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(record.relativeTimeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var fileIcon: String {
        let ext = (record.filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "ppt", "pptx", "key":
            return "play.rectangle.fill"
        case "doc", "docx", "pages":
            return "doc.text.fill"
        case "xls", "xlsx", "numbers":
            return "tablecells.fill"
        case "zip", "rar", "7z":
            return "doc.zipper"
        case "mp4", "mov", "avi":
            return "film.fill"
        case "mp3", "wav", "aac":
            return "music.note"
        case "jpg", "jpeg", "png", "gif":
            return "photo.fill"
        default:
            return "doc"
        }
    }
}

#Preview {
    RecentActivityView(
        records: [
            SortedFileRecord(
                filename: "BLK_S3_Slides.pdf",
                courseCode: "BLK",
                sessionNumber: 3,
                destinationPath: "/Users/example/BLOCKCHAIN/Session 3/BLK_S3_Slides.pdf"
            ),
            SortedFileRecord(
                filename: "ML_S12_Notes.docx",
                courseCode: "ML",
                sessionNumber: 12,
                destinationPath: "/Users/example/MACHINE_LEARNING/Session 12/ML_S12_Notes.docx"
            )
        ],
        onReveal: { _ in }
    )
    .frame(width: 280)
    .padding()
}
