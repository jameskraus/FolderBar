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
            onChange?(resolvedSymbolName)
        }
    }

    var onChange: ((String) -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.symbolName = userDefaults.string(forKey: symbolNameKey) ?? Self.defaultSymbolName
    }

    var isValidSymbol: Bool {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil
    }

    var resolvedSymbolName: String {
        isValidSymbol ? symbolName : Self.defaultSymbolName
    }

    func resetToDefault() {
        symbolName = Self.defaultSymbolName
    }
}

