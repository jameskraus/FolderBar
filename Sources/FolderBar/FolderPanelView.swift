import AppKit
import FolderBarCore
import SwiftUI

struct FolderPanelView: View {
    @ObservedObject var viewModel: FolderSelectionViewModel

    var body: some View {
        Group {
            if let folderURL = viewModel.selectedFolderURL {
                SelectedFolderView(folderURL: folderURL, items: viewModel.items)
            } else {
                EmptyStateView(onChooseFolder: viewModel.chooseFolder)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

private struct EmptyStateView: View {
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 28, weight: .semibold))
            Text("No folder selected")
                .font(.system(size: 13, weight: .semibold))
            Text("Choose a folder to show its files here.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Choose Folder", action: onChooseFolder)
                .buttonStyle(DefaultButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SelectedFolderView: View {
    let folderURL: URL
    let items: [FolderChildItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(folderURL.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                Text(folderURL.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if items.isEmpty {
                Text("No items found.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items.indices, id: \.self) { index in
                            FolderItemRow(item: items[index])
                            if index < items.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct FolderItemRow: View {
    let item: FolderChildItem
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
            Text(item.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            guard hovering != isHovering else { return }
            isHovering = hovering
            if hovering {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            if isHovering {
                isHovering = false
                NSCursor.pop()
            }
        }
    }

    private var icon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: item.url.path)
        image.size = NSSize(width: 20, height: 20)
        return image
    }
}
