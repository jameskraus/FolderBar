import Foundation

public struct FolderSnapshot: Hashable {
    public let folderURL: URL
    public let items: [FolderChildItem]
    public let generatedAt: Date

    public init(folderURL: URL, items: [FolderChildItem], generatedAt: Date = Date()) {
        self.folderURL = folderURL
        self.items = items
        self.generatedAt = generatedAt
    }
}
