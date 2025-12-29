import AppKit
import Foundation
import QuickLookThumbnailing

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private struct ThumbnailKey: Hashable {
        let url: URL
        let width: Int
        let height: Int
        let scaleTimes100: Int

        init(url: URL, size: CGSize, scale: CGFloat) {
            self.url = url
            width = Int(size.width.rounded())
            height = Int(size.height.rounded())
            scaleTimes100 = Int((scale * 100).rounded())
        }

        var nsCacheKey: NSString {
            "\(url.path)|\(width)x\(height)@\(scaleTimes100)" as NSString
        }
    }

    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: [ThumbnailKey: Task<NSImage, Never>] = [:]

    private init() {
        cache.countLimit = 512
    }

    func thumbnail(for url: URL, size: CGSize) async -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let key = ThumbnailKey(url: url, size: size, scale: scale)

        if let cached = cache.object(forKey: key.nsCacheKey) {
            return cached
        }

        if let task = inFlight[key] {
            return await task.value
        }

        let task = Task { [url, size, scale] in
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: scale,
                representationTypes: .thumbnail
            )

            let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let image = representation?.nsImage ?? Self.fallbackIcon(for: url, size: size)
            image.size = size
            return image
        }

        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        cache.setObject(image, forKey: key.nsCacheKey)
        return image
    }

    private static func fallbackIcon(for url: URL, size: CGSize) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = size
        return image
    }
}
