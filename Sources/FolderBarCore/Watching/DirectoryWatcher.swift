import Darwin
import Dispatch
import Foundation

public final class DirectoryWatcher {
    public enum WatcherError: Swift.Error {
        case failedToOpen(path: String, errno: Int32)
    }

    public var onChange: (() -> Void)?

    private let url: URL
    private let debounceInterval: TimeInterval
    private let queue: DispatchQueue
    private var source: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private var fileDescriptor: Int32 = -1

    public init(
        url: URL,
        debounceInterval: TimeInterval = 0.2,
        queue: DispatchQueue = DispatchQueue(label: "FolderBar.DirectoryWatcher")
    ) {
        self.url = url
        self.debounceInterval = debounceInterval
        self.queue = queue
    }

    deinit {
        stop()
    }

    public func start() throws {
        stop()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            throw WatcherError.failedToOpen(path: url.path, errno: errno)
        }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleDebouncedChange()
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if fileDescriptor >= 0 {
                close(fileDescriptor)
                fileDescriptor = -1
            }
        }

        self.source = source
        source.resume()
    }

    public func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        source?.cancel()
        source = nil
    }

    private func scheduleDebouncedChange() {
        debounceWorkItem?.cancel()

        let handler = onChange
        let workItem = DispatchWorkItem {
            handler?()
        }

        debounceWorkItem = workItem

        if debounceInterval <= 0 {
            queue.async(execute: workItem)
        } else {
            queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
        }
    }
}
