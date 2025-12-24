import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let viewModel: FolderSelectionViewModel
    private let updater: FolderBarUpdater
    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let view = SettingsView(
            viewModel: viewModel,
            updater: updater,
            appVersion: appVersion,
            onChooseFolder: { [weak self] in
                guard let self else { return }
                viewModel.chooseFolderFromSettings(presentingWindow: window)
            },
            onResetAll: { [weak self] in
                self?.viewModel.resetAllSettings()
            }
        )
        let hostingController = NSHostingController(rootView: view)
        window.center()
        window.title = "Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        return window
    }()

    init(viewModel: FolderSelectionViewModel, updater: FolderBarUpdater) {
        self.viewModel = viewModel
        self.updater = updater
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return version ?? "0.0.0"
    }
}
