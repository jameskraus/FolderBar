import Foundation
import os
import Sparkle

@MainActor
final class FolderBarUpdater: NSObject, ObservableObject {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "FolderBar"
    private let logger = Logger(subsystem: FolderBarUpdater.subsystem, category: "Updater")

    @Published private(set) var isUpdateAvailable: Bool = false
    @Published private(set) var availableVersionString: String?
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var lastError: String?

    private lazy var sparkleController: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }()

    var isEnabled: Bool {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return false }
        return feedURL != nil
    }

    func start() {
        guard isEnabled else {
            logger.info("Updater disabled (missing SUFeedURL or not running from .app bundle)")
            return
        }

        sparkleController.startUpdater()
    }

    func probeForUpdates() {
        guard isEnabled else { return }
        sparkleController.updater.checkForUpdateInformation()
    }

    func userInitiatedUpdate() {
        guard isEnabled else { return }
        sparkleController.checkForUpdates(nil)
    }

    private var feedURL: URL? {
        guard let feedString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String else {
            return nil
        }
        let trimmed = feedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

extension FolderBarUpdater: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let versionString = item.displayVersionString
        Task { @MainActor [weak self] in
            self?.isUpdateAvailable = true
            self?.availableVersionString = versionString
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor [weak self] in
            self?.isUpdateAvailable = false
            self?.availableVersionString = nil
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        let errorDescription = error.map { String(describing: $0) }
        Task { @MainActor [weak self] in
            self?.lastCheckedAt = Date()
            self?.lastError = errorDescription
        }
    }
}
