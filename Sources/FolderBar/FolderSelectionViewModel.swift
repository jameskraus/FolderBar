import AppKit
import Dispatch
import FolderBarCore
import Foundation
import os

@MainActor
final class FolderSelectionViewModel: ObservableObject {
    @Published private(set) var selectedFolderURL: URL?
    @Published private(set) var items: [FolderChildItem] = []

    private let userDefaults: UserDefaults
    private let selectedFolderKey = "SelectedFolderPath"
    private let scanner = FolderScanner()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FolderBar", category: "FolderSelection")
    private var watcher: DirectoryWatcher?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let path = userDefaults.string(forKey: selectedFolderKey) {
            selectedFolderURL = URL(fileURLWithPath: path)
        }
        if let folderURL = selectedFolderURL {
            startWatching(folderURL)
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "Choose a Folder"
        panel.prompt = "Choose"

        panel.begin { [weak self] response in
            guard let self else { return }
            guard response == .OK, let url = panel.url else { return }
            self.updateSelectedFolder(url)
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
                guard self.selectedFolderURL == folderURL else { return }
                self.items = results
            } catch {
                guard self.selectedFolderURL == folderURL else { return }
                self.logger.error("Failed to scan folder: \(String(describing: error))")
                self.clearSelection()
            }
        }
    }

    private func updateSelectedFolder(_ url: URL) {
        stopWatching()
        selectedFolderURL = url
        userDefaults.set(url.path, forKey: selectedFolderKey)
        items = []
        startWatching(url)
        refreshItems()
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
                    continuation.resume(returning: try scanner.scan(folderURL: folderURL))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
