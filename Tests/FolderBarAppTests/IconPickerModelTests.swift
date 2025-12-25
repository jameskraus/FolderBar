@testable import FolderBarApp
import Foundation
import XCTest

final class IconPickerModelTests: XCTestCase {
    func testRapidTyping_lastInputWins() async {
        let catalog = FixtureCatalog(symbols: [
            "folder",
            "folder.fill",
            "bolt",
            "square.and.arrow.up"
        ])
        let model = await MainActor.run {
            IconPickerModel(catalog: catalog, sleeper: YieldingSleeper(), debounceNanos: 0)
        }

        await MainActor.run {
            model.loadIfNeeded()
        }
        await waitUntil { await MainActor.run { !model.isLoading } }

        await MainActor.run {
            model.filterText = "f"
            model.filterText = "fo"
            model.filterText = "  FOLDer  "
        }

        await waitUntil {
            await MainActor.run {
                model.displayedSymbolNames == ["folder", "folder.fill"]
            }
        }
    }

    func testChangingFilterWhileLoading_appliesAfterLoad() async {
        let catalog = BlockingCatalog(symbols: [
            "folder",
            "folder.fill",
            "bolt"
        ])
        let model = await MainActor.run {
            IconPickerModel(catalog: catalog, sleeper: YieldingSleeper(), debounceNanos: 0)
        }

        await MainActor.run {
            model.loadIfNeeded()
            XCTAssertTrue(model.isLoading)
            model.filterText = "bolt"
        }

        catalog.unblock()

        await waitUntil { await MainActor.run { !model.isLoading } }
        let displayed = await MainActor.run { model.displayedSymbolNames }
        XCTAssertEqual(displayed, ["bolt"])
    }

    func testEmptyCatalog_isNotLoading_andHasNoSymbols() async {
        let catalog = FixtureCatalog(symbols: [])
        let model = await MainActor.run {
            IconPickerModel(catalog: catalog, sleeper: YieldingSleeper(), debounceNanos: 0)
        }

        await MainActor.run {
            model.loadIfNeeded()
        }

        await waitUntil { await MainActor.run { !model.isLoading } }
        let displayed = await MainActor.run { model.displayedSymbolNames }
        XCTAssertEqual(displayed, [])
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 10_000_000,
        _ condition: @escaping @Sendable () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try? await Task.sleep(nanoseconds: pollInterval)
        }
        XCTFail("Condition not met within \(timeout)s")
    }
}

private struct FixtureCatalog: SymbolCatalogLoading {
    let symbols: [String]

    func loadSymbolNames() -> [String] {
        symbols
    }
}

private struct YieldingSleeper: Sleeper {
    func sleep(nanoseconds _: UInt64) async {
        await Task.yield()
    }
}

private final class BlockingCatalog: @unchecked Sendable, SymbolCatalogLoading {
    private let semaphore = DispatchSemaphore(value: 0)
    private let symbols: [String]

    init(symbols: [String]) {
        self.symbols = symbols
    }

    func loadSymbolNames() -> [String] {
        _ = semaphore.wait(timeout: .now() + 2.0)
        return symbols
    }

    func unblock() {
        semaphore.signal()
    }
}
