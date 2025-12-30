import AVFoundation
import Foundation
import UniformTypeIdentifiers

nonisolated protocol VideoDurationLoading: Sendable {
    func durationSeconds(for url: URL) async -> TimeInterval?
}

private struct AVAssetDurationLoader: VideoDurationLoading {
    func durationSeconds(for url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            guard seconds.isFinite, seconds > 0 else { return nil }
            return seconds
        } catch {
            return nil
        }
    }
}

@MainActor
final class VideoDurationCache {
    static let shared = VideoDurationCache()

    private let cache = NSCache<NSString, NSNumber>()
    private var inFlight: [URL: Task<TimeInterval?, Never>] = [:]
    private let loader: any VideoDurationLoading

    init(loader: any VideoDurationLoading = AVAssetDurationLoader()) {
        self.loader = loader
        cache.countLimit = 512
    }

    func durationText(for url: URL) async -> String? {
        guard Self.isVideoFile(url) else { return nil }

        let cacheKey = url.path as NSString

        if let cached = cache.object(forKey: cacheKey) {
            let seconds = cached.doubleValue
            if seconds.isFinite, seconds > 0 {
                return Self.formatDuration(seconds: seconds)
            }
            return nil
        }

        if let task = inFlight[url] {
            return await Self.formatDuration(seconds: task.value)
        }

        let task = Task.detached(priority: .utility) { [loader, url] in
            await loader.durationSeconds(for: url)
        }

        inFlight[url] = task
        let seconds = await task.value
        inFlight[url] = nil

        storeSeconds(seconds, forKey: cacheKey)

        return Self.formatDuration(seconds: seconds)
    }

    private func storeSeconds(_ seconds: TimeInterval?, forKey key: NSString) {
        if let seconds, seconds.isFinite, seconds > 0 {
            cache.setObject(NSNumber(value: seconds), forKey: key)
        } else {
            cache.setObject(NSNumber(value: -1), forKey: key)
        }
    }

    private static func formatDuration(seconds: TimeInterval?) -> String? {
        guard let seconds, seconds.isFinite, seconds > 0 else { return nil }

        let totalSeconds = Int(seconds.rounded())
        guard totalSeconds > 0 else { return nil }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))m\(String(format: "%02d", remainingSeconds))s"
        }

        if minutes > 0 {
            return "\(minutes)m\(String(format: "%02d", remainingSeconds))s"
        }

        return "\(remainingSeconds)s"
    }

    private static func isVideoFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return false }

        if let type = UTType(filenameExtension: ext) {
            return type.conforms(to: .movie) || type.conforms(to: .video)
        }

        return [
            "mp4",
            "mov",
            "m4v",
            "avi",
            "mkv",
            "webm",
            "mpeg",
            "mpg"
        ].contains(ext)
    }
}
