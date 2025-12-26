import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let viewModel: FolderSelectionViewModel
    private let updater: FolderBarUpdater
    private let iconSettings: StatusItemIconSettings
    private let appSigningSummary: String?
    private var previousActivationPolicy: NSApplication.ActivationPolicy?
    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
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
        window.minSize = NSSize(width: 500, height: 560)
        window.center()
        window.title = "Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.delegate = self
        return window
    }()

    init(viewModel: FolderSelectionViewModel, updater: FolderBarUpdater, iconSettings: StatusItemIconSettings) {
        self.viewModel = viewModel
        self.updater = updater
        self.iconSettings = iconSettings
        appSigningSummary = AppSigningInfo.warningSummary()
        super.init()
    }

    func show() {
        beginAppActivationForSettings()
        window.makeKeyAndOrderFront(nil)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return version ?? "0.0.0"
    }

    func windowWillClose(_: Notification) {
        restoreActivationPolicyIfNeeded()
    }

    private func beginAppActivationForSettings() {
        if previousActivationPolicy == nil {
            previousActivationPolicy = NSApp.activationPolicy()
        }
        if NSApp.activationPolicy() != .regular {
            _ = NSApp.setActivationPolicy(.regular)
        }
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restoreActivationPolicyIfNeeded() {
        guard let policy = previousActivationPolicy else { return }
        previousActivationPolicy = nil
        guard NSApp.activationPolicy() != policy else { return }
        DispatchQueue.main.async {
            _ = NSApp.setActivationPolicy(policy)
        }
    }
}
