import AppKit
import Foundation

@MainActor
final class StatusItemIconSettings: ObservableObject {
    private let userDefaults: UserDefaults
    private let symbolNameKey = "StatusItemSymbolName"

    static let defaultSymbolName = "folder.fill"

    @Published var symbolName: String {
        didSet {
            userDefaults.set(symbolName, forKey: symbolNameKey)
            updateResolvedSymbolName()
            onChange?(resolvedSymbolName)
        }
    }

    var onChange: ((String) -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let stored = userDefaults.string(forKey: symbolNameKey) ?? Self.defaultSymbolName
        symbolName = stored
        resolvedSymbolName = stored
        isValidSymbol = true
        updateResolvedSymbolName()
    }

    @Published private(set) var resolvedSymbolName: String
    @Published private(set) var isValidSymbol: Bool

    func resetToDefault() {
        symbolName = Self.defaultSymbolName
    }

    private func updateResolvedSymbolName() {
        if NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil {
            resolvedSymbolName = symbolName
            isValidSymbol = true
        } else {
            resolvedSymbolName = Self.defaultSymbolName
            isValidSymbol = false
        }
    }
}
