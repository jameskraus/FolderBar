import Foundation

enum SFSymbolCatalog {
    static func loadSymbolNames() -> [String] {
        let candidates = [
            "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/symbol_order.plist"
        ]

        for path in candidates {
            if let symbols = loadPlistStringArray(atPath: path), !symbols.isEmpty {
                return symbols
            }
        }

        return []
    }

    private static func loadPlistStringArray(atPath path: String) -> [String]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
            return nil
        }

        if let array = plist as? [String] {
            return array
        }

        if let dict = plist as? [String: Any] {
            for key in ["symbols", "symbolNames", "orderedSymbols"] {
                if let array = dict[key] as? [String] {
                    return array
                }
            }
        }

        return nil
    }
}

