import Foundation

public struct FolderConfig: Identifiable, Codable, Hashable {
    public let id: UUID
    public let folderURL: URL
    public var displayName: String?
    public var symbolName: String?

    public init(
        id: UUID = UUID(),
        folderURL: URL,
        displayName: String? = nil,
        symbolName: String? = nil
    ) {
        self.id = id
        self.folderURL = folderURL
        self.displayName = displayName
        self.symbolName = symbolName
    }

    public var resolvedDisplayName: String {
        displayName ?? folderURL.lastPathComponent
    }
}
