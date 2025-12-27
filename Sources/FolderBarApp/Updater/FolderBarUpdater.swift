import AppKit
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
    @Published private(set) var needsAppManagementPermission: Bool = false

    private lazy var sparkleController: SPUStandardUpdaterController = .init(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)

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

    func openPrivacyAndSecuritySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") else { return }
        NSWorkspace.shared.open(url)
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
    nonisolated func updater(_: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let versionString = item.displayVersionString
        Task { @MainActor [weak self] in
            self?.isUpdateAvailable = true
            self?.availableVersionString = versionString
        }
    }

    nonisolated func updaterDidNotFindUpdate(_: SPUUpdater) {
        Task { @MainActor [weak self] in
            self?.isUpdateAvailable = false
            self?.availableVersionString = nil
        }
    }

    nonisolated func updater(_: SPUUpdater, didAbortWithError error: any Error) {
        handleSparkleError(error)
    }

    nonisolated func updater(_: SPUUpdater, didFinishUpdateCycleFor _: SPUUpdateCheck, error: (any Error)?) {
        Task { @MainActor [weak self] in
            self?.lastCheckedAt = Date()
            if let error {
                self?.applySparkleError(error)
            } else {
                self?.lastError = nil
                self?.needsAppManagementPermission = false
            }
        }
    }

    private nonisolated func handleSparkleError(_ error: any Error) {
        Task { @MainActor [weak self] in
            self?.lastCheckedAt = Date()
            self?.applySparkleError(error)
        }
    }

    @MainActor
    private func applySparkleError(_ error: any Error) {
        let nsError = error as NSError
        if Self.isNoUpdateFound(nsError) {
            lastError = nil
            needsAppManagementPermission = false
            return
        }
        lastError = Self.formatError(nsError)
        needsAppManagementPermission = Self.isAppManagementWriteDenied(nsError)
    }

    private static func isNoUpdateFound(_ error: NSError) -> Bool {
        error.domain == SUSparkleErrorDomain && error.code == Int(SUError.noUpdateError.rawValue)
    }

    private static func isAppManagementWriteDenied(_ error: NSError) -> Bool {
        if error.domain == SUSparkleErrorDomain,
           error.code == Int(SUError.installationWriteNoPermissionError.rawValue) {
            return true
        }
        return false
    }

    private static func formatError(_ error: NSError) -> String {
        var parts: [String] = [error.localizedDescription]
        if let reason = error.localizedFailureReason, !reason.isEmpty {
            parts.append(reason)
        }
        if let suggestion = error.localizedRecoverySuggestion, !suggestion.isEmpty {
            parts.append(suggestion)
        }
        parts.append("(\(error.domain) \(error.code))")
        return parts.joined(separator: " ")
    }
}
