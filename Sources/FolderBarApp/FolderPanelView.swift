import AppKit
import FolderBarCore
import SwiftUI
import UniformTypeIdentifiers

struct FolderPanelView: View {
    @ObservedObject var viewModel: FolderSelectionViewModel
    @ObservedObject var updater: FolderBarUpdater
    let onOpenSettings: () -> Void
    let onRequestDismiss: (() -> Void)?

    init(
        viewModel: FolderSelectionViewModel,
        updater: FolderBarUpdater,
        onOpenSettings: @escaping () -> Void,
        onRequestDismiss: (() -> Void)? = nil
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _updater = ObservedObject(wrappedValue: updater)
        self.onOpenSettings = onOpenSettings
        self.onRequestDismiss = onRequestDismiss
    }

    var body: some View {
        Group {
            if let folderURL = viewModel.selectedFolderURL {
                SelectedFolderView(
                    folderURL: folderURL,
                    items: viewModel.items,
                    scrollToken: viewModel.scrollToken,
                    now: viewModel.now,
                    updater: updater,
                    onOpenSettings: onOpenSettings,
                    onRequestDismiss: onRequestDismiss
                )
            } else {
                EmptyStateView(
                    onChooseFolder: viewModel.chooseFolderFromPopover,
                    updater: updater,
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
    @ObservedObject var updater: FolderBarUpdater
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
            FooterMenuBar(updater: updater, onOpenSettings: onOpenSettings)
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
    @ObservedObject var updater: FolderBarUpdater
    let onOpenSettings: () -> Void
    let onRequestDismiss: (() -> Void)?

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
                                let lastItemID = items.last?.id
                                ForEach(items) { item in
                                    FolderItemRow(item: item, now: now, onRequestDismiss: onRequestDismiss)
                                    if item.id != lastItemID {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(height: PanelLayout.listHeight)
                        .onChange(of: scrollToken) {
                            proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                        }
                    }
                    Divider()
                }
                .frame(maxWidth: .infinity)
                .frame(height: PanelLayout.listContainerHeight)
            }
            FooterMenuBar(updater: updater, onOpenSettings: onOpenSettings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private enum ScrollAnchor {
        static let top = "scrollTop"
    }
}

private struct FooterMenuBar: View {
    @ObservedObject var updater: FolderBarUpdater
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            if updater.isUpdateAvailable {
                Button(action: onOpenSettings) {
                    Label("Update available", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Menu {
                Button("Settings…", action: onOpenSettings)
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
        }
        .frame(height: PanelLayout.footerHeight)
        .padding(.leading, PanelLayout.headerHorizontalPadding)
        .padding(.trailing, PanelLayout.footerTrailingPadding)
    }
}

private struct FolderItemDragPayload: Transferable {
    let url: URL
    let suggestedName: String

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: { $0.url })
            .suggestedFileName { $0.suggestedName }

        DataRepresentation(exportedContentType: .utf8PlainText) { item in
            Data(item.url.path.utf8)
        }
    }
}

private struct FolderItemRow: View {
    let item: FolderChildItem
    let now: Date
    let onRequestDismiss: (() -> Void)?
    @State private var isHovering = false
    @State private var thumbnail: NSImage?
    @State private var videoDurationText: String?

    private let thumbnailSize: CGFloat = PanelLayout.thumbnailSize

    var body: some View {
        HStack(spacing: 10) {
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
            .contentShape(Rectangle())
            .draggable(FolderItemDragPayload(url: item.url, suggestedName: item.name))
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

            Menu {
                Button("Reveal in Finder") {
                    revealInFinder()
                }
                Button("Copy to Clipboard") {
                    copyToClipboard()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
        }
        .padding(.vertical, PanelLayout.rowVerticalPadding)
        .padding(.horizontal, PanelLayout.rowHorizontalPadding)
        .task(id: item.url) { @MainActor in
            thumbnail = nil
            videoDurationText = nil
            let size = CGSize(width: thumbnailSize, height: thumbnailSize)

            async let loadedThumbnail = ThumbnailCache.shared.thumbnail(for: item.url, size: size)
            async let loadedVideoDurationText = VideoDurationCache.shared.durationText(for: item.url)

            thumbnail = await loadedThumbnail
            videoDurationText = await loadedVideoDurationText
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
        if let videoDurationText {
            parts.append(videoDurationText)
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

    private func revealInFinder() {
        onRequestDismiss?()
        let targetURL = resolveRevealURL()
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
        activateFinderIfNeeded()
    }

    private func resolveRevealURL() -> URL {
        if FileManager.default.fileExists(atPath: item.url.path) {
            return item.url
        }
        return item.url.deletingLastPathComponent()
    }

    private func activateFinderIfNeeded(retries: Int = 2) {
        let bundleIdentifier = "com.apple.finder"
        let options: NSApplication.ActivationOptions = [
            .activateAllWindows
        ]

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                finder.activate(options: options)
            } else if retries > 0 {
                activateFinderIfNeeded(retries: retries - 1)
            }
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        let pbItem = NSPasteboardItem()
        pbItem.setString(item.url.absoluteString, forType: .fileURL)
        pbItem.setString(item.url.path, forType: .string)

        pasteboard.clearContents()
        pasteboard.writeObjects([pbItem])
    }
}
