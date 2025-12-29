import AppKit
import Foundation
import QuickLookThumbnailing

nonisolated protocol ThumbnailGenerating: Sendable {
    func generateThumbnail(for url: URL, size: CGSize, scale: CGFloat) async -> NSImage?
}

private struct QuickLookThumbnailGenerator: ThumbnailGenerating {
    func generateThumbnail(for url: URL, size: CGSize, scale: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        return representation?.nsImage
    }
}

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
    private let generator: any ThumbnailGenerating
    private let scaleProvider: @Sendable () -> CGFloat

    init(
        generator: any ThumbnailGenerating = QuickLookThumbnailGenerator(),
        scaleProvider: @escaping @Sendable () -> CGFloat = { NSScreen.main?.backingScaleFactor ?? 2 }
    ) {
        self.generator = generator
        self.scaleProvider = scaleProvider
        cache.countLimit = 512
    }

    func thumbnail(for url: URL, size: CGSize) async -> NSImage {
        let scale = scaleProvider()
        let key = ThumbnailKey(url: url, size: size, scale: scale)

        if let cached = cache.object(forKey: key.nsCacheKey) {
            return cached
        }

        if let task = inFlight[key] {
            return await task.value
        }

        let task = Task { [generator, url, size, scale] in
            let generated = await generator.generateThumbnail(for: url, size: size, scale: scale)
            let image = generated ?? Self.fallbackIcon(for: url, size: size)
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
