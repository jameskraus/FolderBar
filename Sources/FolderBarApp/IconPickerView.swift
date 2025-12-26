import SwiftUI

struct IconPickerView: View {
    @ObservedObject var iconSettings: StatusItemIconSettings

    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var model = IconPickerModel()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            Divider()

            content
        }
        .frame(width: 560, height: 640)
        .onAppear {
            model.loadIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Menu Bar Icon")
                    .font(.system(size: 14, weight: .semibold))

                Text("Selected: \(iconSettings.resolvedSymbolName)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Reset") {
                iconSettings.resetToDefault()
            }

            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TextField("Filter icons…", text: $model.filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)

                Spacer()

                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("\(model.displayedSymbolNames.count) icons")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                if model.isLoading {
                    EmptyView()
                } else if model.displayedSymbolNames.isEmpty {
                    Text(model.filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No symbols available." : "No results.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(40)
                } else {
                    let selectedSymbolName = iconSettings.resolvedSymbolName
                    IconGrid(
                        symbols: model.displayedSymbolNames,
                        selectedSymbolName: selectedSymbolName
                    ) { symbolName in
                        iconSettings.symbolName = symbolName
                    }
                    .transaction { $0.animation = nil }
                }
            }
        }
    }
}

private struct IconGrid: View {
    let symbols: [String]
    let selectedSymbolName: String
    let onSelect: (String) -> Void

    private static let columnCount = 9
    private static let cellSize: CGFloat = 44
    private static let cellSpacing: CGFloat = 10
    private static let contentPadding: CGFloat = 20

    var body: some View {
        let rows = (symbols.count + Self.columnCount - 1) / Self.columnCount

        LazyVStack(spacing: Self.cellSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                IconGridRow(
                    symbols: symbols,
                    selectedSymbolName: selectedSymbolName,
                    rowIndex: row,
                    onSelect: onSelect
                )
            }
        }
        .padding(Self.contentPadding)
        .animation(nil, value: symbols)
    }

    private struct IconGridRow: View {
        let symbols: [String]
        let selectedSymbolName: String
        let rowIndex: Int
        let onSelect: (String) -> Void

        var body: some View {
            HStack(spacing: IconGrid.cellSpacing) {
                ForEach(0..<IconGrid.columnCount, id: \.self) { column in
                    let index = rowIndex * IconGrid.columnCount + column
                    if index < symbols.count {
                        let symbolName = symbols[index]
                        IconCell(
                            symbolName: symbolName,
                            isSelected: symbolName == selectedSymbolName
                        ) {
                            onSelect(symbolName)
                        }
                    } else {
                        Color.clear
                            .frame(width: IconGrid.cellSize, height: IconGrid.cellSize)
                    }
                }
            }
        }
    }
}

private struct IconCell: View {
    let symbolName: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color(NSColor.separatorColor).opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(6)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}
