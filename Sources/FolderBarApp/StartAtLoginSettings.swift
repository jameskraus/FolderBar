import Foundation
import ServiceManagement

@MainActor
protocol StartAtLoginManaging {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

@MainActor
struct MainAppStartAtLoginManager: StartAtLoginManaging {
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
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?
    @Published private(set) var shouldShowIndeterminateGuidance = false

    private let manager: any StartAtLoginManaging
    private var didAttemptEnable = false

    init(
        manager: any StartAtLoginManaging = MainAppStartAtLoginManager()
    ) {
        self.manager = manager
        status = manager.status
        updateDerivedState()
    }

    func refresh() {
        status = manager.status

        if status != .notFound {
            didAttemptEnable = false
        }

        updateDerivedState()
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        didAttemptEnable = enabled

        do {
            if enabled {
                if !isEnabled {
                    try manager.register()
                }
            } else {
                if isEnabled {
                    try manager.unregister()
                }
            }
        } catch {
            errorMessage = Self.userFacingErrorMessage(error)
        }

        refresh()
    }

    func openSystemSettingsLoginItems() {
        manager.openSystemSettingsLoginItems()
    }

    var isEnabled: Bool {
        switch status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    var isStatusIndeterminate: Bool {
        status == .notFound
    }

    private func updateDerivedState() {
        shouldShowIndeterminateGuidance = didAttemptEnable && status == .notFound
    }

    private static func userFacingErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String, !reason.isEmpty {
            return reason
        }
        return nsError.localizedDescription
    }
}
