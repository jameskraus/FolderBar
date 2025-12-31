import AppKit
import Foundation
import os
import SwiftUI

@MainActor
private final class MenuBarExtraServices: ObservableObject {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "FolderBar"
    private let logger = Logger(subsystem: MenuBarExtraServices.subsystem, category: "MenuBarExtra")

    let viewModel: FolderSelectionViewModel
    let updater: FolderBarUpdater
    let iconSettings: StatusItemIconSettings
    let startAtLogin: StartAtLoginSettings

    @Published private(set) var resolvedSymbolName: String

    private var updateProbeTimer: Timer?
    private lazy var settingsWindowController = SettingsWindowController(
        viewModel: viewModel,
        updater: updater,
        iconSettings: iconSettings,
        startAtLogin: startAtLogin
    )

    init() {
        viewModel = FolderSelectionViewModel()
        updater = FolderBarUpdater()
        iconSettings = StatusItemIconSettings()
        startAtLogin = StartAtLoginSettings()
        resolvedSymbolName = iconSettings.resolvedSymbolName

        iconSettings.onChange = { [weak self] symbolName in
            self?.resolvedSymbolName = symbolName
        }

        _ = NSApp.setActivationPolicy(.accessory)
        updater.start()
        scheduleUpdateProbes()
    }

    func openSettings() {
        settingsWindowController.show()
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

public struct FolderBarMenuBarExtraScene: Scene {
    @StateObject private var services = MenuBarExtraServices()

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuBarPanelContainer(
                viewModel: services.viewModel,
                updater: services.updater,
                onOpenSettings: { services.openSettings() }
            )
            .frame(width: PanelLayout.contentSize.width, height: PanelLayout.contentSize.height)
            .onAppear { services.viewModel.panelDidOpen() }
            .onDisappear { services.viewModel.panelDidClose() }
        } label: {
            Image(systemName: services.resolvedSymbolName)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarPanelContainer: View {
    @ObservedObject var viewModel: FolderSelectionViewModel
    @ObservedObject var updater: FolderBarUpdater
    let onOpenSettings: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FolderPanelView(
            viewModel: viewModel,
            updater: updater,
            onOpenSettings: onOpenSettings,
            onRequestDismiss: dismissMenuBarExtra
        )
    }

    private func dismissMenuBarExtra() {
        let window = NSApp.keyWindow
        dismiss()
        if let window, window.level != .normal {
            window.orderOut(nil)
        }
    }
}
