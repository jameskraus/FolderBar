import AppKit
import FolderBarCore
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var thumbnail: NSImage?

    private let thumbnailSize: CGFloat = 48

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: thumbnail ?? icon)
                .resizable()
                .frame(width: thumbnailSize, height: thumbnailSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(metadataText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onDrag {
            let provider = NSItemProvider(item: item.url as NSURL, typeIdentifier: UTType.fileURL.identifier)
            provider.suggestedName = item.name
            let pathData = Data(item.url.path.utf8)
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.utf8PlainText.identifier,
                visibility: .all
            ) { completion in
                completion(pathData, nil)
                return nil
            }
            return provider
        }
        .onAppear {
            let size = CGSize(width: thumbnailSize, height: thumbnailSize)
            ThumbnailCache.shared.requestThumbnail(for: item.url, size: size) { image in
                thumbnail = image
            }
        }
        .onChange(of: item.url) { _ in
            thumbnail = nil
            let size = CGSize(width: thumbnailSize, height: thumbnailSize)
            ThumbnailCache.shared.requestThumbnail(for: item.url, size: size) { image in
                thumbnail = image
            }
        }
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
        image.size = NSSize(width: thumbnailSize, height: thumbnailSize)
        return image
    }

    private var metadataText: String {
        "\(typeLabel) • \(relativeDateText)"
    }

    private var typeLabel: String {
        if item.isDirectory {
            return "Folder"
        }
        let ext = item.url.pathExtension
        if ext.isEmpty {
            return "File"
        }
        return ext.uppercased()
    }

    private var relativeDateText: String {
        Self.relativeFormatter.localizedString(for: item.creationDate, relativeTo: Date())
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
