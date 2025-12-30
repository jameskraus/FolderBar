@testable import FolderBarApp
import ServiceManagement
import XCTest

@MainActor
final class StartAtLoginSettingsTests: XCTestCase {
    func testInit_reflectsCurrentSystemState() async {
        let manager = FakeStartAtLoginManager(status: .enabled)
        let settings = StartAtLoginSettings(manager: manager)

        XCTAssertTrue(settings.isEnabled)
    }

    func testSetEnabled_registersOnSuccess() async {
        let manager = FakeStartAtLoginManager(status: .notRegistered)
        let settings = StartAtLoginSettings(manager: manager)

        settings.setEnabled(true)

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertTrue(settings.isEnabled)
    }

    func testSetEnabled_surfacesErrorsAndRevertsState() async {
        let manager = FakeStartAtLoginManager(status: .notRegistered)
        manager.registerError = TestError.example

        let settings = StartAtLoginSettings(manager: manager)

        settings.setEnabled(true)

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertFalse(settings.isEnabled)
        XCTAssertNotNil(settings.errorMessage)
    }

    func testNotFound_allowsEnableAttempt() async {
        let manager = FakeStartAtLoginManager(status: .notFound)
        let settings = StartAtLoginSettings(manager: manager)

        XCTAssertFalse(settings.isEnabled)
        XCTAssertTrue(settings.isStatusIndeterminate)
        XCTAssertFalse(settings.shouldShowIndeterminateGuidance)

        settings.setEnabled(true)

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertTrue(settings.isEnabled)
        XCTAssertFalse(settings.shouldShowIndeterminateGuidance)
    }

    func testRequiresApproval_mapsToEnabled() async {
        let manager = FakeStartAtLoginManager(status: .requiresApproval)
        let settings = StartAtLoginSettings(manager: manager)

        XCTAssertTrue(settings.isEnabled)
        XCTAssertTrue(settings.needsApproval)
    }

    func testNotFound_showsIndeterminateGuidanceAfterEnableAttemptIfStatusRemainsNotFound() async {
        let manager = FakeStartAtLoginManager(status: .notFound)
        manager.statusAfterRegister = .notFound

        let settings = StartAtLoginSettings(manager: manager)

        XCTAssertTrue(settings.isStatusIndeterminate)
        XCTAssertFalse(settings.shouldShowIndeterminateGuidance)

        settings.setEnabled(true)

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertTrue(settings.isStatusIndeterminate)
        XCTAssertTrue(settings.shouldShowIndeterminateGuidance)
    }
}

private enum TestError: Error {
    case example
}

@MainActor
private final class FakeStartAtLoginManager: StartAtLoginManaging {
    var status: SMAppService.Status { statusValue }

    private(set) var registerCallCount: Int = 0
    private(set) var unregisterCallCount: Int = 0

    var registerError: Error?
    var unregisterError: Error?
    var statusAfterRegister: SMAppService.Status = .enabled

    private var statusValue: SMAppService.Status

    init(status: SMAppService.Status) {
        statusValue = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError { throw registerError }
        statusValue = statusAfterRegister
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError { throw unregisterError }
        statusValue = .notRegistered
    }

    func openSystemSettingsLoginItems() {}
}
