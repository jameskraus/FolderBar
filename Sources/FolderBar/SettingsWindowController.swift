import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let viewModel: FolderSelectionViewModel
    private let updater: FolderBarUpdater
    private let iconSettings: StatusItemIconSettings
    private let appSigningSummary: String?
    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let view = SettingsView(
            viewModel: viewModel,
            updater: updater,
            iconSettings: iconSettings,
            appVersion: appVersion,
            appSigningSummary: appSigningSummary,
            onChooseFolder: { [weak self] in
                guard let self else { return }
                viewModel.chooseFolderFromSettings(presentingWindow: window)
            },
            onResetAll: { [weak self] in
                self?.viewModel.resetAllSettings()
                self?.iconSettings.resetToDefault()
            }
        )
        let hostingController = NSHostingController(rootView: view)
        window.minSize = NSSize(width: 500, height: 480)
        window.center()
        window.title = "Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        return window
    }()

    init(viewModel: FolderSelectionViewModel, updater: FolderBarUpdater, iconSettings: StatusItemIconSettings) {
        self.viewModel = viewModel
        self.updater = updater
        self.iconSettings = iconSettings
        self.appSigningSummary = AppSigningInfo.warningSummary()
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
