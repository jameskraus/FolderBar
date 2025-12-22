import AppKit
import Foundation
@preconcurrency import QuickLookThumbnailing

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: [(NSImage) -> Void]] = [:]

    private init() {
        cache.countLimit = 512
    }

    func requestThumbnail(for url: URL, size: CGSize, completion: @escaping (NSImage) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        if var callbacks = inFlight[url] {
            callbacks.append(completion)
            inFlight[url] = callbacks
            return
        }

        inFlight[url] = [completion]

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        Task { @MainActor [weak self, url, size] in
            guard let self else { return }
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: scale,
                representationTypes: .thumbnail
            )

            let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let image = representation?.nsImage ?? fallbackIcon(for: url, size: size)
            image.size = size
            cache.setObject(image, forKey: url as NSURL)
            let callbacks = inFlight.removeValue(forKey: url) ?? []
            callbacks.forEach { $0(image) }
        }
    }

    private func fallbackIcon(for url: URL, size: CGSize) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = size
        return image
    }
}
