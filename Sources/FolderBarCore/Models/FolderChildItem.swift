import Foundation

public struct FolderChildItem: Identifiable, Hashable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let creationDate: Date

    public init(url: URL, name: String, isDirectory: Bool, creationDate: Date) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.creationDate = creationDate
    }

    public var id: URL {
        url
    }
}
