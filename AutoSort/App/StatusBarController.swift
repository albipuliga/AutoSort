import AppKit
import Combine
import SwiftUI

/// Manages the status bar item and menu popover
@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel: MenuBarViewModel
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
        let statusView = StatusItemView()
        statusView.onClick = { [weak self] in
            self?.togglePopover()
        }
        statusView.onDragEnter = { [weak self] in
            self?.showPopover()
        }
        statusView.isWatching = viewModel.isWatching
        statusItem.view = statusView
        statusItem.length = statusView.intrinsicContentSize.width
    }

    private func configurePopover() {
        let rootView = MenuBarView(viewModel: viewModel)
            .frame(width: 280)
        let hostingController = NSHostingController(rootView: rootView)

        popover.contentViewController = hostingController
        popover.behavior = .applicationDefined
        popover.animates = false
        hostingController.view.layoutSubtreeIfNeeded()
        popover.contentSize = hostingController.view.fittingSize
    }

    private func bindViewModel() {
        viewModel.$isWatching
            .receive(on: RunLoop.main)
            .sink { [weak self] isWatching in
                (self?.statusItem.view as? StatusItemView)?.isWatching = isWatching
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
        guard let statusView = statusItem.view else { return }
        if let contentView = popover.contentViewController?.view {
            contentView.alphaValue = 1.0
        }
        if !popover.isShown {
            popover.show(relativeTo: statusView.bounds, of: statusView, preferredEdge: .minY)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func closePopoverAnimated(delay: TimeInterval, fadeDuration: TimeInterval) {
        guard popover.isShown, !isClosing else { return }
        isClosing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            guard self.popover.isShown else {
                self.isClosing = false
                return
            }

            if let contentView = self.popover.contentViewController?.view {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = fadeDuration
                    contentView.animator().alphaValue = 0.0
                } completionHandler: { [weak self] in
                    self?.popover.performClose(nil)
                    contentView.alphaValue = 1.0
                    self?.isClosing = false
                }
            } else {
                self.popover.performClose(nil)
                self.isClosing = false
            }
        }
    }
}
