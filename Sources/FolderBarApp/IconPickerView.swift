import SwiftUI

struct IconPickerView: View {
    @ObservedObject var iconSettings: StatusItemIconSettings

    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var model = IconPickerModel()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, IconPickerLayout.horizontalPadding)
                .padding(.vertical, IconPickerLayout.headerVerticalPadding)

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
        IconPickerBody(
            filterText: $model.filterText,
            isLoading: model.isLoading,
            displayedCount: model.displayedSymbolNames.count,
            gridState: gridState
        )
    }

    private var gridState: IconPickerBody.GridState {
        if model.isLoading {
            return .loading
        }

        let trimmedFilter = model.filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.displayedSymbolNames.isEmpty {
            return .empty(message: trimmedFilter.isEmpty ? "No symbols available." : "No results.")
        }

        return .symbols(
            model.displayedSymbolNames,
            revision: model.displayedSymbolNamesRevision,
            selectedSymbolName: iconSettings.resolvedSymbolName
        ) { symbolName in
            iconSettings.symbolName = symbolName
        }
    }
}

private enum IconPickerLayout {
    static let horizontalPadding: CGFloat = 20
    static let bodyTopPadding: CGFloat = 14
    static let headerVerticalPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 12
    static let emptyStatePadding: CGFloat = 40
}

private struct IconPickerBody: View {
    @Binding var filterText: String
    let isLoading: Bool
    let displayedCount: Int
    let gridState: GridState

    var body: some View {
        VStack(alignment: .leading, spacing: IconPickerLayout.sectionSpacing) {
            filterBar
            gridRegion
        }
        .padding(.horizontal, IconPickerLayout.horizontalPadding)
        .padding(.top, IconPickerLayout.bodyTopPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            TextField("Filter icons…", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("\(displayedCount) icons")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var gridRegion: some View {
        ZStack {
            switch gridState {
            case .loading:
                ProgressView()
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            case let .empty(message):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(IconPickerLayout.emptyStatePadding)

            case let .symbols(symbols, revision, selectedSymbolName, onSelect):
                IconPickerCollectionView(
                    symbols: symbols,
                    symbolsRevision: revision,
                    selectedSymbolName: selectedSymbolName,
                    onSelect: onSelect
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    enum GridState {
        case loading
        case empty(message: String)
        case symbols([String], revision: Int, selectedSymbolName: String, onSelect: (String) -> Void)
    }
}
