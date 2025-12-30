@testable import FolderBarApp
import XCTest

@MainActor
final class VideoDurationCacheTests: XCTestCase {
    func testDurationText_nonVideo_returnsNilAndDoesNotCallLoader() async {
        let loader = FakeVideoDurationLoader(nextValues: [12])
        let cache = VideoDurationCache(loader: loader)
        let url = URL(fileURLWithPath: "/tmp/file.txt")

        let text = await cache.durationText(for: url)
        let callCount = await loader.getCallCount()

        XCTAssertNil(text)
        XCTAssertEqual(callCount, 0)
    }

    func testDurationText_video_formatsAndCaches() async {
        let loader = FakeVideoDurationLoader(nextValues: [12.3])
        let cache = VideoDurationCache(loader: loader)
        let url = URL(fileURLWithPath: "/tmp/video.mp4")

        let first = await cache.durationText(for: url)
        let second = await cache.durationText(for: url)
        let callCount = await loader.getCallCount()

        XCTAssertEqual(first, "00m12s")
        XCTAssertEqual(second, "00m12s")
        XCTAssertEqual(callCount, 1)
    }

    func testDurationText_video_cachesNilResult() async {
        let loader = FakeVideoDurationLoader(nextValues: [nil, 65])
        let cache = VideoDurationCache(loader: loader)
        let url = URL(fileURLWithPath: "/tmp/video.mp4")

        let first = await cache.durationText(for: url)
        let second = await cache.durationText(for: url)
        let callCount = await loader.getCallCount()

        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(callCount, 1)
    }
}

private actor FakeVideoDurationLoader: VideoDurationLoading {
    private var nextValues: [TimeInterval?]
    private var callCount = 0

    init(nextValues: [TimeInterval?]) {
        self.nextValues = nextValues
    }

    nonisolated func durationSeconds(for _: URL) async -> TimeInterval? {
        await nextDuration()
    }

    private func nextDuration() -> TimeInterval? {
        callCount += 1
        guard !nextValues.isEmpty else { return nil }
        return nextValues.removeFirst()
    }

    func getCallCount() -> Int {
        callCount
    }
}
