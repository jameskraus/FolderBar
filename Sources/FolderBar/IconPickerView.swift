import SwiftUI

struct IconPickerView: View {
    @ObservedObject var iconSettings: StatusItemIconSettings

    @Environment(\.presentationMode) private var presentationMode
    @State private var filterText = ""
    @State private var symbolNames: [String] = []
    @State private var isLoading = true

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
                DispatchQueue.main.async {
                    symbolNames = loaded
                    isLoading = false
                }
            }
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
                    Text("\(filteredSymbols.count) icons")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                LazyVGrid(columns: Self.columns, spacing: 10) {
                    ForEach(filteredSymbols, id: \.self) { symbolName in
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

    private var filteredSymbols: [String] {
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return symbolNames }
        return symbolNames.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    private static let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 44, maximum: 56), spacing: 10, alignment: .center)
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
        .help(symbolName)
    }
}
