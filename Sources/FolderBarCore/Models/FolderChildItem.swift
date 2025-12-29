import Foundation

public struct FolderChildItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let creationDate: Date
    public let fileSize: Int64?

    public init(url: URL, name: String, isDirectory: Bool, creationDate: Date, fileSize: Int64?) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.creationDate = creationDate
        self.fileSize = fileSize
    }

    public var id: URL {
        url
    }
}
