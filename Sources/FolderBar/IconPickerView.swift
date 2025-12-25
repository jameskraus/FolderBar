import SwiftUI

struct IconPickerView: View {
    @ObservedObject var iconSettings: StatusItemIconSettings

    @Environment(\.presentationMode) private var presentationMode
    @State private var filterText = ""
    @State private var symbolNames: [String] = []
    @State private var symbolNamesLowercased: [String] = []
    @State private var displayedSymbolNames: [String] = []
    @State private var isLoading = true
    @State private var pendingFilterWorkItem: DispatchWorkItem?

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
            guard symbolNames.isEmpty else { return }
            isLoading = true
            DispatchQueue.global(qos: .userInitiated).async {
                let loaded = SFSymbolCatalog.loadSymbolNames()
                let lowered = loaded.map { $0.lowercased() }
                DispatchQueue.main.async {
                    symbolNames = loaded
                    symbolNamesLowercased = lowered
                    displayedSymbolNames = loaded
                    isLoading = false
                }
            }
        }
        .onChange(of: filterText) { _ in
            scheduleFilterUpdate()
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
                TextField("Filter icons…", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("\(displayedSymbolNames.count) icons")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                if isLoading {
                    EmptyView()
                } else if displayedSymbolNames.isEmpty {
                    Text(symbolNames.isEmpty ? "No symbols available." : "No results.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(40)
                } else {
                    LazyVGrid(columns: Self.columns, spacing: 10) {
                        ForEach(displayedSymbolNames, id: \.self) { symbolName in
                            IconCell(
                                symbolName: symbolName,
                                isSelected: symbolName == iconSettings.resolvedSymbolName
                            ) {
                                iconSettings.symbolName = symbolName
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private func scheduleFilterUpdate() {
        pendingFilterWorkItem?.cancel()

        let filter = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let currentSymbols = symbolNames
        let currentLowered = symbolNamesLowercased

        if filter.isEmpty {
            displayedSymbolNames = currentSymbols
            return
        }

        let workItem = DispatchWorkItem { [filter] in
            var results: [String] = []
            results.reserveCapacity(512)
            for (name, lowered) in zip(currentSymbols, currentLowered) {
                if lowered.contains(filter) {
                    results.append(name)
                }
            }
            DispatchQueue.main.async {
                displayedSymbolNames = results
            }
        }

        pendingFilterWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private static let columns: [GridItem] = [
        GridItem(.fixed(44), spacing: 10, alignment: .center),
        GridItem(.fixed(44), spacing: 10, alignment: .center),
        GridItem(.fixed(44), spacing: 10, alignment: .center),
        GridItem(.fixed(44), spacing: 10, alignment: .center),
        GridItem(.fixed(44), spacing: 10, alignment: .center),
        GridItem(.fixed(44), spacing: 10, alignment: .center),
        GridItem(.fixed(44), spacing: 10, alignment: .center),
        GridItem(.fixed(44), spacing: 10, alignment: .center),
        GridItem(.fixed(44), spacing: 10, alignment: .center)
    ]
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
