import AppKit
import FolderBarCore
import SwiftUI
import UniformTypeIdentifiers

struct FolderPanelView: View {
    @ObservedObject var viewModel: FolderSelectionViewModel
    let onOpenSettings: () -> Void

    var body: some View {
        Group {
            if let folderURL = viewModel.selectedFolderURL {
                SelectedFolderView(
                    folderURL: folderURL,
                    items: viewModel.items,
                    scrollToken: viewModel.scrollToken,
                    now: viewModel.now,
                    onOpenSettings: onOpenSettings
                )
            } else {
                EmptyStateView(
                    onChooseFolder: viewModel.chooseFolderFromPopover,
                    onOpenSettings: onOpenSettings
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, PanelLayout.topPadding)
        .padding(.bottom, PanelLayout.bottomPadding)
        .ignoresSafeArea(.container, edges: .top)
    }
}

private struct EmptyStateView: View {
    let onChooseFolder: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
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
            Spacer(minLength: 0)
            FooterMenuBar(onOpenSettings: onOpenSettings)
        }
        .padding(.horizontal, PanelLayout.headerHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SelectedFolderView: View {
    let folderURL: URL
    let items: [FolderChildItem]
    let scrollToken: UUID
    let now: Date
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PanelLayout.headerSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(folderURL.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                Text(folderURL.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, PanelLayout.headerHorizontalPadding)
            .padding(.trailing, 24)

            if items.isEmpty {
                Text("No items found.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PanelLayout.headerHorizontalPadding)
                Spacer(minLength: 0)
            } else {
                VStack(spacing: 0) {
                    Divider()
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                Color.clear
                                    .frame(height: 0)
                                    .id(ScrollAnchor.top)
                                ForEach(items.indices, id: \.self) { index in
                                    FolderItemRow(item: items[index], now: now)
                                    if index < items.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(height: PanelLayout.listHeight)
                        .onChange(of: scrollToken) { _ in
                            proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                        }
                    }
                    Divider()
                }
                .frame(maxWidth: .infinity)
                .frame(height: PanelLayout.listContainerHeight)
            }
            FooterMenuBar(onOpenSettings: onOpenSettings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private enum ScrollAnchor {
        static let top = "scrollTop"
    }
}

private struct FooterMenuBar: View {
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Menu {
                Button("Settings…", action: onOpenSettings)
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PanelLayout.headerHorizontalPadding)
        .padding(.top, 4)
    }
}

private struct FolderItemRow: View {
    let item: FolderChildItem
    let now: Date
    @State private var isHovering = false
    @State private var thumbnail: NSImage?

    private let thumbnailSize: CGFloat = PanelLayout.thumbnailSize

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
        .padding(.vertical, PanelLayout.rowVerticalPadding)
        .padding(.horizontal, PanelLayout.rowHorizontalPadding)
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
        var parts: [String] = [relativeDateText]
        if let sizeText {
            parts.append(sizeText)
        }
        return parts.joined(separator: "  ")
    }

    private var relativeDateText: String {
        let delta = now.timeIntervalSince(item.creationDate)
        if delta > -60, delta < 60 {
            return "A moment ago"
        }
        if Calendar.current.isDateInToday(item.creationDate) {
            return Self.relativeFormatter.localizedString(for: item.creationDate, relativeTo: now)
        }
        return Self.dateFormatter.string(from: item.creationDate)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var sizeText: String? {
        guard !item.isDirectory, let fileSize = item.fileSize else { return nil }
        return Self.byteCountFormatter.string(fromByteCount: fileSize)
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()
}
