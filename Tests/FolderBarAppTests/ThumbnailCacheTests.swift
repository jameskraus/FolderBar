@testable import FolderBarApp
import AppKit
import Foundation
import XCTest

final class ThumbnailCacheTests: XCTestCase {
    func testThumbnailDedupesInFlightRequests() async throws {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let fileURL = tempDirectory.appendingPathComponent("file.txt")
        XCTAssertTrue(fileManager.createFile(atPath: fileURL.path, contents: Data("x".utf8)))

        let generator = BlockingThumbnailGenerator()
        let cache = await MainActor.run {
            ThumbnailCache(generator: generator, scaleProvider: { 2 })
        }
        let size = CGSize(width: 48, height: 48)

        let first = Task { @MainActor in
            await cache.thumbnail(for: fileURL, size: size)
        }

        await generator.waitUntilFirstRequestStarts()

        let second = Task { @MainActor in
            await cache.thumbnail(for: fileURL, size: size)
        }

        await generator.release()

        let firstImage = await first.value
        let secondImage = await second.value

        XCTAssertEqual(firstImage.size, size)
        XCTAssertEqual(secondImage.size, size)
        let callCount = await generator.callCount
        XCTAssertEqual(callCount, 1)
    }
}

private actor BlockingThumbnailGenerator: ThumbnailGenerating {
    private var callCountValue: Int = 0
    private var didStartContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func generateThumbnail(for _: URL, size: CGSize, scale _: CGFloat) async -> NSImage? {
        callCountValue += 1

        if callCountValue == 1 {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                releaseContinuation = continuation
                didStartContinuation?.resume()
                didStartContinuation = nil
            }
        }

        return NSImage(size: size)
    }

    func waitUntilFirstRequestStarts() async {
        guard callCountValue == 0 else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            didStartContinuation = continuation
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    var callCount: Int { callCountValue }
}
