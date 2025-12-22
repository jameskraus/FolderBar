import AppKit
import Foundation
import QuickLookThumbnailing

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: [((NSImage) -> Void)]] = [:]

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
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let self else { return }
            Task { @MainActor in
                let image = representation?.nsImage ?? self.fallbackIcon(for: url, size: size)
                image.size = size
                self.cache.setObject(image, forKey: url as NSURL)
                let callbacks = self.inFlight.removeValue(forKey: url) ?? []
                callbacks.forEach { $0(image) }
            }
        }
    }

    private func fallbackIcon(for url: URL, size: CGSize) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = size
        return image
    }
}
