@testable import FolderBarApp
import Foundation
import XCTest

final class StatusItemIconSettingsTests: XCTestCase {
    func testInitWithInvalidStoredSymbol_fallsBackToDefault() async {
        let suiteName = "FolderBarTests.\(UUID().uuidString)"
        let (symbolName, resolved, isValid, defaultSymbolName) = await MainActor.run {
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set("not.a.real.symbol", forKey: "StatusItemSymbolName")

            let settings = StatusItemIconSettings(userDefaults: defaults)
            return (settings.symbolName, settings.resolvedSymbolName, settings.isValidSymbol, StatusItemIconSettings.defaultSymbolName)
        }

        XCTAssertEqual(symbolName, "not.a.real.symbol")
        XCTAssertEqual(resolved, defaultSymbolName)
        XCTAssertFalse(isValid)
    }

    func testSettingInvalidSymbol_updatesResolvedName_andFiresOnChangeWithResolvedValue() async {
        let suiteName = "FolderBarTests.\(UUID().uuidString)"
        let (resolved, isValid, lastChange, defaultSymbolName) = await MainActor.run {
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)

            let settings = StatusItemIconSettings(userDefaults: defaults)
            var lastChange: String?
            settings.onChange = { lastChange = $0 }
            settings.symbolName = "not.a.real.symbol"

            return (settings.resolvedSymbolName, settings.isValidSymbol, lastChange, StatusItemIconSettings.defaultSymbolName)
        }

        XCTAssertEqual(resolved, defaultSymbolName)
        XCTAssertFalse(isValid)
        XCTAssertEqual(lastChange, defaultSymbolName)
    }
}
