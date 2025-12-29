import Foundation
import ServiceManagement

nonisolated protocol StartAtLoginManaging: Sendable {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

nonisolated struct MainAppStartAtLoginManager: StartAtLoginManaging {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
final class StartAtLoginSettings: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    private let manager: any StartAtLoginManaging
    private let userDefaults: UserDefaults
    private let userDefaultsKey = "StartAtLoginEnabled"

    init(
        manager: any StartAtLoginManaging = MainAppStartAtLoginManager(),
        userDefaults: UserDefaults = .standard
    ) {
        self.manager = manager
        self.userDefaults = userDefaults

        let initialStatus = manager.status
        status = initialStatus
        isEnabled = Self.isEnabled(status: initialStatus)

        if userDefaults.object(forKey: userDefaultsKey) == nil {
            userDefaults.set(isEnabled, forKey: userDefaultsKey)
        } else {
            reconcileWithStoredIntentIfNeeded()
        }
    }

    func refresh() {
        status = manager.status
        isEnabled = Self.isEnabled(status: status)
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                try manager.register()
            } else {
                try manager.unregister()
            }
            userDefaults.set(enabled, forKey: userDefaultsKey)
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
    }

    func openSystemSettingsLoginItems() {
        manager.openSystemSettingsLoginItems()
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    var isSupported: Bool {
        status != .notFound
    }

    private func reconcileWithStoredIntentIfNeeded() {
        guard isSupported else { return }

        let desired = userDefaults.bool(forKey: userDefaultsKey)
        guard desired != isEnabled else { return }
        setEnabled(desired)
    }

    private static func isEnabled(status: SMAppService.Status) -> Bool {
        switch status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }
}
