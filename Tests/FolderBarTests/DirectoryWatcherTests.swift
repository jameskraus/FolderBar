@testable import FolderBarCore
import Foundation
import XCTest

final class DirectoryWatcherTests: XCTestCase {
    func testChangesDebouncesBurstIntoSingleEvent() async throws {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let watcher = DirectoryWatcher(url: tempDirectory, debounceInterval: 0.75)
        addTeardownBlock {
            Task { await watcher.stop() }
        }

        let stream = try await watcher.changes()
        let events = EventCounter()
        let didReceiveFirst = expectation(description: "DirectoryWatcher yielded an event")

        let consumer = Task {
            for await _ in stream {
                let count = await events.increment()
                if count == 1 {
                    didReceiveFirst.fulfill()
                }
            }
        }
        addTeardownBlock {
            consumer.cancel()
        }

        for index in 0..<10 {
            let url = tempDirectory.appendingPathComponent("File-\(index).txt")
            XCTAssertTrue(fileManager.createFile(atPath: url.path, contents: Data("x".utf8)))
        }

        await fulfillment(of: [didReceiveFirst], timeout: 5.0)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let count = await events.count
        XCTAssertEqual(count, 1)
    }
}

private actor EventCounter {
    private var value: Int = 0

    func increment() -> Int {
        value += 1
        return value
    }

    var count: Int { value }
}
