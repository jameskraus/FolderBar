import AppKit
import Dispatch
import FolderBarCore
import Foundation
import os

@MainActor
final class FolderSelectionViewModel: ObservableObject {
    @Published private(set) var selectedFolderURL: URL?
    @Published private(set) var items: [FolderChildItem] = []
    @Published private(set) var scrollToken = UUID()
    @Published private(set) var now = Date()
    @Published private(set) var isFolderPickerPresented = false

    private let userDefaults: UserDefaults
    private let selectedFolderKey = "SelectedFolderPath"
    private let scanner = FolderScanner()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FolderBar", category: "FolderSelection")
    private var watcher: DirectoryWatcher?
    private var refreshTimer: Timer?
    private var activeOpenPanel: NSOpenPanel?
    private weak var activeOpenPanelPresentingWindow: NSWindow?
    private var openPanelPreviousActivationPolicy: NSApplication.ActivationPolicy?
    private var shouldReopenPopoverAfterPickerCloses = false

    var requestClosePopover: (() -> Void)?
    var requestReopenPopover: (() -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let path = userDefaults.string(forKey: selectedFolderKey) {
            selectedFolderURL = URL(fileURLWithPath: path)
        }
        if let folderURL = selectedFolderURL {
            startWatching(folderURL)
        }
    }

    func chooseFolderFromPopover() {
        shouldReopenPopoverAfterPickerCloses = true
        requestClosePopover?()
        guard !isFolderPickerPresented else {
            focusFolderPicker()
            return
        }
        isFolderPickerPresented = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            presentOpenPanel(presentingWindow: nil)
        }
    }

    func chooseFolderFromSettings(presentingWindow: NSWindow?) {
        guard !isFolderPickerPresented else {
            focusFolderPicker()
            return
        }
        shouldReopenPopoverAfterPickerCloses = false
        isFolderPickerPresented = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            presentOpenPanel(presentingWindow: presentingWindow)
        }
    }

    func refreshItems() {
        guard let folderURL = selectedFolderURL else {
            items = []
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await scanOnBackground(folderURL)
                guard selectedFolderURL == folderURL else { return }
                items = results
            } catch {
                guard selectedFolderURL == folderURL else { return }
                logger.error("Failed to scan folder: \(String(describing: error))")
                clearSelection()
            }
        }
    }

    func panelDidOpen() {
        scrollToken = UUID()
        now = Date()
        refreshItems()
        startRelativeTimeTimer()
    }

    func panelDidClose() {
        stopRelativeTimeTimer()
    }

    func resetAllSettings() {
        stopWatching()
        selectedFolderURL = nil
        items = []
        if let bundleID = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: bundleID)
        } else {
            userDefaults.removeObject(forKey: selectedFolderKey)
        }
    }

    private func startRelativeTimeTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
            }
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    private func stopRelativeTimeTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func updateSelectedFolder(_ url: URL) {
        stopWatching()
        selectedFolderURL = url
        userDefaults.set(url.path, forKey: selectedFolderKey)
        items = []
        startWatching(url)
        refreshItems()
    }

    private func presentOpenPanel(
        presentingWindow: NSWindow?
    ) {
        guard activeOpenPanel == nil else {
            focusFolderPicker()
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "Choose a Folder"
        panel.prompt = "Choose"
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        activeOpenPanel = panel
        activeOpenPanelPresentingWindow = presentingWindow

        beginAppActivationForOpenPanel()
        presentingWindow?.makeKeyAndOrderFront(nil)

        let handleResponse: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self else { return }
            if response == .OK, let url = panel.url {
                updateSelectedFolder(url)
            }
            activeOpenPanel = nil
            activeOpenPanelPresentingWindow = nil
            isFolderPickerPresented = false
            restoreActivationPolicyIfNeeded()
            if shouldReopenPopoverAfterPickerCloses {
                requestReopenPopover?()
            }
        }

        if let presentingWindow {
            panel.beginSheetModal(for: presentingWindow, completionHandler: handleResponse)
        } else {
            panel.begin(completionHandler: handleResponse)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            panel.orderFrontRegardless()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    private func focusFolderPicker() {
        guard let activeOpenPanel else {
            isFolderPickerPresented = false
            restoreActivationPolicyIfNeeded()
            return
        }

        beginAppActivationForOpenPanel()
        activeOpenPanelPresentingWindow?.makeKeyAndOrderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            activeOpenPanel.orderFrontRegardless()
            activeOpenPanel.makeKeyAndOrderFront(nil)
        }
    }

    private func beginAppActivationForOpenPanel() {
        if openPanelPreviousActivationPolicy == nil {
            openPanelPreviousActivationPolicy = NSApp.activationPolicy()
        }
        if NSApp.activationPolicy() != .regular {
            _ = NSApp.setActivationPolicy(.regular)
        }
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restoreActivationPolicyIfNeeded() {
        guard activeOpenPanel == nil else { return }
        guard let policy = openPanelPreviousActivationPolicy else { return }
        openPanelPreviousActivationPolicy = nil
        guard NSApp.activationPolicy() != policy else { return }
        DispatchQueue.main.async {
            _ = NSApp.setActivationPolicy(policy)
        }
    }

    private func clearSelection() {
        stopWatching()
        selectedFolderURL = nil
        items = []
        userDefaults.removeObject(forKey: selectedFolderKey)
    }

    private func startWatching(_ url: URL) {
        let watcher = DirectoryWatcher(url: url, debounceInterval: 0.2)
        watcher.onChange = { [weak self] in
            Task { @MainActor in
                self?.refreshItems()
            }
        }
        do {
            try watcher.start()
            self.watcher = watcher
        } catch {
            logger.error("Failed to start watcher: \(String(describing: error))")
            clearSelection()
        }
    }

    private func stopWatching() {
        watcher?.stop()
        watcher = nil
    }

    private func scanOnBackground(_ folderURL: URL) async throws -> [FolderChildItem] {
        let scanner = scanner
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try continuation.resume(returning: scanner.scan(folderURL: folderURL))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
