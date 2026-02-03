import AppKit
import Combine
import SwiftUI

/// Manages the status bar item and menu popover
@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel: MenuBarViewModel
    private var statusItemView: StatusItemView?
    private var cancellables = Set<AnyCancellable>()
    private var isClosing = false

    init(viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()

        configureStatusItem()
        configurePopover()
        bindViewModel()
        bindNotifications()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let statusView = StatusItemView()
        statusView.onClick = { [weak self] in
            self?.togglePopover()
        }
        statusView.onDragEnter = { [weak self] in
            self?.showPopover()
        }
        statusView.isWatching = viewModel.isWatching
        statusView.translatesAutoresizingMaskIntoConstraints = false

        button.image = nil
        button.title = ""
        button.addSubview(statusView)

        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            statusView.topAnchor.constraint(equalTo: button.topAnchor),
            statusView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        statusItem.length = statusView.intrinsicContentSize.width
        statusItemView = statusView
    }

    private func configurePopover() {
        let rootView = MenuBarView(viewModel: viewModel)
            .frame(width: 280)
        let hostingController = NSHostingController(rootView: rootView)

        popover.contentViewController = hostingController
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.contentSize = hostingController.view.fittingSize
    }

    private func bindViewModel() {
        viewModel.$isWatching
            .receive(on: RunLoop.main)
            .sink { [weak self] isWatching in
                self?.statusItemView?.isWatching = isWatching
            }
            .store(in: &cancellables)
    }

    private func bindNotifications() {
        NotificationCenter.default.publisher(for: Constants.UI.menuBarShouldClose)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.closePopoverAnimated(
                    delay: Constants.UI.menuBarCloseDelay,
                    fadeDuration: Constants.UI.menuBarFadeDuration
                )
            }
            .store(in: &cancellables)
    }

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let statusButton = statusItem.button else { return }
        if let contentView = popover.contentViewController?.view {
            contentView.alphaValue = 1.0
        }
        if !popover.isShown {
            popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func closePopoverAnimated(delay: TimeInterval, fadeDuration: TimeInterval) {
        guard popover.isShown, !isClosing else { return }
        isClosing = true

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if delay > 0 {
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            guard self.popover.isShown else {
                self.isClosing = false
                return
            }

            if let contentView = self.popover.contentViewController?.view {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = fadeDuration
                    contentView.animator().alphaValue = 0.0
                } completionHandler: { [weak self] in
                    Task { @MainActor in
                        self?.finishClosingPopover(resetAlpha: true)
                    }
                }
            } else {
                self.finishClosingPopover(resetAlpha: false)
            }
        }
    }

    @MainActor
    private func finishClosingPopover(resetAlpha: Bool) {
        let contentView = popover.contentViewController?.view
        popover.performClose(nil)
        if resetAlpha {
            contentView?.alphaValue = 1.0
        }
        isClosing = false
    }
}
