import Foundation

@MainActor
final class IconPickerModel: ObservableObject {
    @Published var filterText: String = "" {
        didSet { scheduleFilterUpdate() }
    }
    @Published private(set) var displayedSymbolNames: [String] = []
    @Published private(set) var isLoading = true

    private var allSymbolNames: [String] = []
    private var allSymbolNamesLowercased: [String] = []
    private var filterTask: Task<Void, Never>?

    func loadIfNeeded() {
        guard allSymbolNames.isEmpty else { return }

        isLoading = true
        Task { @MainActor in
            let loaded = await Task.detached(priority: .userInitiated) {
                SFSymbolCatalog.loadSymbolNames()
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
            displayedSymbolNames = allSymbolNames
        } else {
            displayedSymbolNames = Self.filteredSymbols(filter: filter, symbols: allSymbolNames, lowered: allSymbolNamesLowercased)
        }
    }

    private func scheduleFilterUpdate() {
        let filter = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let symbols = allSymbolNames
        let lowered = allSymbolNamesLowercased

        filterTask?.cancel()
        filterTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }

            if filter.isEmpty {
                displayedSymbolNames = symbols
                return
            }

            let results = await Task.detached(priority: .userInitiated) { [filter, symbols, lowered] in
                Self.filteredSymbols(filter: filter, symbols: symbols, lowered: lowered)
            }.value

            if Task.isCancelled { return }
            displayedSymbolNames = results
        }
    }

    nonisolated private static func filteredSymbols(filter: String, symbols: [String], lowered: [String]) -> [String] {
        var results: [String] = []
        results.reserveCapacity(512)
        for (name, loweredName) in zip(symbols, lowered) {
            if loweredName.contains(filter) {
                results.append(name)
            }
        }
        return results
    }
}
