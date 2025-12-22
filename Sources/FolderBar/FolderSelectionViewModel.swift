import AppKit
import Foundation

@MainActor
final class FolderSelectionViewModel: ObservableObject {
    @Published private(set) var selectedFolderURL: URL?

    private let userDefaults: UserDefaults
    private let selectedFolderKey = "SelectedFolderPath"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let path = userDefaults.string(forKey: selectedFolderKey) {
            selectedFolderURL = URL(fileURLWithPath: path)
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

    private func updateSelectedFolder(_ url: URL) {
        selectedFolderURL = url
        userDefaults.set(url.path, forKey: selectedFolderKey)
    }
}
