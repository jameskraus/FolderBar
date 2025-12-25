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
                    LazyVGrid(columns: Self.columns, spacing: 10) {
                        ForEach(model.displayedSymbolNames, id: \.self) { symbolName in
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
