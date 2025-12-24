import AppKit
import os
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "FolderBar"
    private let logger = Logger(subsystem: AppDelegate.subsystem, category: "Lifecycle")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let folderSelectionViewModel = FolderSelectionViewModel()
    private lazy var settingsWindowController = SettingsWindowController(viewModel: folderSelectionViewModel)
    private lazy var panelController = MenuBarPanelController(
        statusItem: statusItem,
        rootView: AnyView(
            FolderPanelView(
                viewModel: folderSelectionViewModel,
                onOpenSettings: { [weak self] in
                    self?.folderSelectionViewModel.requestClosePopover?()
                    self?.settingsWindowController.show()
                }
            )
        ),
        contentSize: PanelLayout.contentSize,
        onShow: { [weak folderSelectionViewModel] in
            folderSelectionViewModel?.panelDidOpen()
        },
        onClose: { [weak folderSelectionViewModel] in
            folderSelectionViewModel?.panelDidClose()
        }
    )

    func applicationDidFinishLaunching(_: Notification) {
        logger.info("Application finished launching")

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "FolderBar")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePanel(_:))
        }

        folderSelectionViewModel.requestClosePopover = { [weak self] in
            self?.panelController.close()
        }
        folderSelectionViewModel.requestReopenPopover = { [weak self] in
            self?.panelController.show()
        }
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_: Notification) {
        logger.info("Application will terminate")
    }

    @objc private func togglePanel(_: Any?) {
        panelController.toggle()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
