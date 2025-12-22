import Foundation

public struct FolderScanner: Sendable {
    public init() {}

    public func scan(folderURL: URL) throws -> [FolderChildItem] {
        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .creationDateKey,
            .contentModificationDateKey
        ]

        let childURLs = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        )

        let items = try childURLs.map { url -> FolderChildItem in
            let resourceValues = try url.resourceValues(forKeys: resourceKeys)
            let name = resourceValues.name ?? url.lastPathComponent
            let isDirectory = resourceValues.isDirectory ?? false
            let creationDate = resourceValues.creationDate
                ?? resourceValues.contentModificationDate
                ?? Date.distantPast

            return FolderChildItem(
                url: url,
                name: name,
                isDirectory: isDirectory,
                creationDate: creationDate
            )
        }

        return items.sorted { lhs, rhs in
            lhs.creationDate > rhs.creationDate
        }
    }
}
