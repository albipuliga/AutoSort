import AppKit

/// Custom status bar view that supports drag detection and click handling
final class StatusItemView: NSView {
    private let imageView = NSImageView()
    private let dotView = NSView()

    var isWatching: Bool = false {
        didSet {
            dotView.isHidden = !isWatching
        }
    }

    var onClick: (() -> Void)?
    var onDragEnter: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 28, height: NSStatusBar.system.thickness)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canAcceptDrop(sender) else { return [] }
        onDragEnter?()
        return []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        false
    }

    private func setupView() {
        wantsLayer = true
        registerForDraggedTypes([.fileURL])

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = NSImage(
            systemSymbolName: "folder.badge.gearshape",
            accessibilityDescription: "AutoSort"
        )
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        imageView.contentTintColor = .labelColor

        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 3
        dotView.layer?.backgroundColor = NSColor.systemGreen.cgColor
        dotView.isHidden = true

        addSubview(imageView)
        addSubview(dotView)

        NSLayoutConstraint.activate([
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),

            dotView.widthAnchor.constraint(equalToConstant: 6),
            dotView.heightAnchor.constraint(equalToConstant: 6),
            dotView.topAnchor.constraint(equalTo: imageView.topAnchor, constant: -1),
            dotView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 2)
        ])
    }

    private func canAcceptDrop(_ sender: NSDraggingInfo) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        return sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: options)
    }
}
