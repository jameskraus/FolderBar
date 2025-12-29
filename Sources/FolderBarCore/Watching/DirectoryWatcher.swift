import Darwin
import Dispatch
import Foundation

public actor DirectoryWatcher {
    public enum WatcherError: Swift.Error {
        case failedToOpen(path: String, errno: Int32)
    }

    private let url: URL
    private let debounceInterval: TimeInterval
    private let queue: DispatchQueue
    private var source: DispatchSourceFileSystemObject?
    private var continuation: AsyncStream<Void>.Continuation?
    private var debounceTask: Task<Void, Never>?
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
        debounceTask?.cancel()
        debounceTask = nil

        continuation?.finish()
        continuation = nil

        source?.cancel()
        source = nil

        fileDescriptor = -1
    }

    public func changes() throws -> AsyncStream<Void> {
        stop()

        var streamContinuation: AsyncStream<Void>.Continuation?
        let stream = AsyncStream<Void> { continuation in
            streamContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.stop() }
            }
        }

        guard let continuation = streamContinuation else { return stream }

        do {
            try start(continuation: continuation)
        } catch {
            continuation.finish()
            throw error
        }

        return stream
    }

    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil

        let continuation = continuation
        self.continuation = nil
        continuation?.finish()

        if let source {
            self.source = nil
            fileDescriptor = -1
            source.cancel()
            return
        }

        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func scheduleDebouncedYield() {
        debounceTask?.cancel()
        debounceTask = nil
        guard let continuation else { return }

        if debounceInterval <= 0 {
            continuation.yield(())
            return
        }

        let nanosecondsDouble = debounceInterval * 1_000_000_000
        let nanoseconds = UInt64(max(0, min(nanosecondsDouble, Double(UInt64.max))))

        debounceTask = Task { @Sendable [continuation] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            continuation.yield(())
        }
    }

    private func start(continuation: AsyncStream<Void>.Continuation) throws {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            throw WatcherError.failedToOpen(path: url.path, errno: errno)
        }

        fileDescriptor = fd
        self.continuation = continuation

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.scheduleDebouncedYield() }
        }

        source.setCancelHandler {
            close(fd)
        }

        self.source = source
        source.resume()
    }
}
