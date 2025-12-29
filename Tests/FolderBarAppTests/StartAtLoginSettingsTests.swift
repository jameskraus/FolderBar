@testable import FolderBarApp
import ServiceManagement
import XCTest

@MainActor
final class StartAtLoginSettingsTests: XCTestCase {
    func testInit_setsDefaultsToCurrentSystemState() async {
        let suiteName = "FolderBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let manager = FakeStartAtLoginManager(status: .enabled)
        let settings = StartAtLoginSettings(manager: manager, userDefaults: defaults)

        XCTAssertTrue(settings.isEnabled)
        XCTAssertTrue(defaults.bool(forKey: "StartAtLoginEnabled"))
    }

    func testSetEnabled_registersAndPersistsOnSuccess() async {
        let suiteName = "FolderBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let manager = FakeStartAtLoginManager(status: .notRegistered)
        let settings = StartAtLoginSettings(manager: manager, userDefaults: defaults)

        settings.setEnabled(true)

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertTrue(defaults.bool(forKey: "StartAtLoginEnabled"))
        XCTAssertTrue(settings.isEnabled)
    }

    func testSetEnabled_surfacesErrorsAndRevertsState() async {
        let suiteName = "FolderBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let manager = FakeStartAtLoginManager(status: .notRegistered)
        manager.registerError = TestError.example

        let settings = StartAtLoginSettings(manager: manager, userDefaults: defaults)

        settings.setEnabled(true)

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertFalse(settings.isEnabled)
        XCTAssertNotNil(settings.errorMessage)
        XCTAssertFalse(defaults.bool(forKey: "StartAtLoginEnabled"))
    }
}

private enum TestError: Error {
    case example
}

private final class FakeStartAtLoginManager: @unchecked Sendable, StartAtLoginManaging {
    var status: SMAppService.Status { statusValue }

    private(set) var registerCallCount: Int = 0
    private(set) var unregisterCallCount: Int = 0

    var registerError: Error?
    var unregisterError: Error?

    private var statusValue: SMAppService.Status

    init(status: SMAppService.Status) {
        statusValue = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError { throw registerError }
        statusValue = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError { throw unregisterError }
        statusValue = .notRegistered
    }

    func openSystemSettingsLoginItems() {}
}
