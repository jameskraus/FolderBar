import AppKit
import Foundation
import os
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "FolderBar"
    private let logger = Logger(subsystem: AppDelegate.subsystem, category: "Lifecycle")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let folderSelectionViewModel = FolderSelectionViewModel()
    private let updater = FolderBarUpdater()
    private var updateProbeTimer: Timer?
    private lazy var settingsWindowController = SettingsWindowController(viewModel: folderSelectionViewModel, updater: updater)
    private lazy var panelController = MenuBarPanelController(
        statusItem: statusItem,
        rootView: AnyView(
            FolderPanelView(
                viewModel: folderSelectionViewModel,
                updater: updater,
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

        updater.start()
        scheduleUpdateProbes()
    }

    func applicationWillTerminate(_: Notification) {
        logger.info("Application will terminate")
        updateProbeTimer?.invalidate()
        updateProbeTimer = nil
    }

    @objc private func togglePanel(_: Any?) {
        panelController.toggle()
    }

    private func scheduleUpdateProbes() {
        guard updater.isEnabled else { return }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await self?.probeForUpdatesIfDue(minimumInterval: 6 * 60 * 60)
        }

        updateProbeTimer?.invalidate()
        updateProbeTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.probeForUpdatesIfDue(minimumInterval: 24 * 60 * 60)
            }
        }
    }

    private func probeForUpdatesIfDue(minimumInterval: TimeInterval) async {
        guard updater.isEnabled else { return }

        let defaultsKey = "FolderBar.lastUpdateProbeAt"
        let now = Date()
        if let lastProbe = UserDefaults.standard.object(forKey: defaultsKey) as? Date,
           now.timeIntervalSince(lastProbe) < minimumInterval {
            return
        }

        UserDefaults.standard.set(now, forKey: defaultsKey)
        updater.probeForUpdates()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
