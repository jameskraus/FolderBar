import Foundation

protocol SymbolCatalogLoading: Sendable {
    func loadSymbolNames() -> [String]
}

struct SystemSymbolCatalog: SymbolCatalogLoading {
    func loadSymbolNames() -> [String] {
        SFSymbolCatalog.loadSymbolNames()
    }
}

protocol Sleeper: Sendable {
    func sleep(nanoseconds: UInt64) async
}

struct TaskSleeper: Sleeper {
    func sleep(nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

@MainActor
final class IconPickerModel: ObservableObject {
    @Published var filterText: String = "" {
        didSet { scheduleFilterUpdate() }
    }
    @Published private(set) var displayedSymbolNames: [String] = []
    @Published private(set) var displayedSymbolNamesRevision: Int = 0
    @Published private(set) var isLoading = true

    private var allSymbolNames: [String] = []
    private var allSymbolNamesLowercased: [String] = []
    private var filterTask: Task<Void, Never>?

    private let catalog: any SymbolCatalogLoading
    private let sleeper: any Sleeper
    private let debounceNanos: UInt64

    init(
        catalog: any SymbolCatalogLoading = SystemSymbolCatalog(),
        sleeper: any Sleeper = TaskSleeper(),
        debounceNanos: UInt64 = 150_000_000
    ) {
        self.catalog = catalog
        self.sleeper = sleeper
        self.debounceNanos = debounceNanos
    }

    func loadIfNeeded() {
        guard allSymbolNames.isEmpty else { return }

        filterTask?.cancel()
        isLoading = true
        Task { @MainActor in
            let catalog = catalog
            let loaded = await Task.detached(priority: .userInitiated) {
                catalog.loadSymbolNames()
            }.value

            allSymbolNames = loaded
            allSymbolNamesLowercased = loaded.map { $0.lowercased() }
            applyFilterImmediately()
            isLoading = false
        }
    }

    private func applyFilterImmediately() {
        let filter = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if filter.isEmpty {
            updateDisplayedSymbolNames(allSymbolNames)
        } else {
            updateDisplayedSymbolNames(Self.filteredSymbols(filter: filter, symbols: allSymbolNames, lowered: allSymbolNamesLowercased))
        }
    }

    private func scheduleFilterUpdate() {
        filterTask?.cancel()
        filterTask = Task { @MainActor in
            await sleeper.sleep(nanoseconds: debounceNanos)
            if Task.isCancelled { return }

            if isLoading { return }

            let filter = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let symbols = allSymbolNames
            let lowered = allSymbolNamesLowercased

            if filter.isEmpty {
                updateDisplayedSymbolNames(symbols)
                return
            }

            let results = await Task.detached(priority: .userInitiated) { [filter, symbols, lowered] in
                Self.filteredSymbols(filter: filter, symbols: symbols, lowered: lowered)
            }.value

            if Task.isCancelled { return }
            updateDisplayedSymbolNames(results)
        }
    }

    private func updateDisplayedSymbolNames(_ newValue: [String]) {
        displayedSymbolNames = newValue
        displayedSymbolNamesRevision &+= 1
    }

    nonisolated private static func filteredSymbols(filter: String, symbols: [String], lowered: [String]) -> [String] {
        var results: [String] = []
        results.reserveCapacity(512)
        for (name, loweredName) in zip(symbols, lowered) where loweredName.contains(filter) {
            results.append(name)
        }
        return results
    }
}
