import AppKit
import os
import SwiftUI

@MainActor
struct IconPickerCollectionView: NSViewRepresentable {
    let symbols: [String]
    let symbolsRevision: Int
    let selectedSymbolName: String
    let onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 44, height: 44)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.delegate = context.coordinator
        collectionView.register(
            IconCollectionViewItem.self,
            forItemWithIdentifier: IconCollectionViewItem.reuseIdentifier
        )

        let dataSource = NSCollectionViewDiffableDataSource<Section, String>(collectionView: collectionView) { collectionView, indexPath, symbolName in
            let item = collectionView.makeItem(withIdentifier: IconCollectionViewItem.reuseIdentifier, for: indexPath)
            guard let iconItem = item as? IconCollectionViewItem else { return item }
            iconItem.setSymbolName(symbolName)
            return iconItem
        }

        context.coordinator.dataSource = dataSource
        context.coordinator.collectionView = collectionView

        let scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        applySnapshotIfNeeded(symbolsRevision: symbolsRevision, symbols: symbols, coordinator: context.coordinator, animating: false)
        updateSelection(selectedSymbolName: selectedSymbolName, coordinator: context.coordinator)

        return scrollView
    }

    func updateNSView(_: NSScrollView, context: Context) {
        context.coordinator.onSelect = onSelect
        applySnapshotIfNeeded(symbolsRevision: symbolsRevision, symbols: symbols, coordinator: context.coordinator, animating: false)
        updateSelection(selectedSymbolName: selectedSymbolName, coordinator: context.coordinator)
    }

    private func applySnapshotIfNeeded(
        symbolsRevision: Int,
        symbols: [String],
        coordinator: Coordinator,
        animating: Bool
    ) {
        guard coordinator.lastSymbolsRevision != symbolsRevision else { return }
        coordinator.lastSymbolsRevision = symbolsRevision

        var snapshot = NSDiffableDataSourceSnapshot<Section, String>()
        snapshot.appendSections([.main])
        snapshot.appendItems(symbols, toSection: .main)
        coordinator.dataSource?.apply(snapshot, animatingDifferences: animating)
    }

    private func updateSelection(selectedSymbolName: String, coordinator: Coordinator) {
        guard let collectionView = coordinator.collectionView else { return }

        if let indexPath = coordinator.dataSource?.indexPath(for: selectedSymbolName) {
            collectionView.selectItems(at: [indexPath], scrollPosition: [])
        } else {
            collectionView.deselectAll(nil)
        }
    }

    enum Section: Hashable {
        case main
    }

    final class Coordinator: NSObject, NSCollectionViewDelegate {
        var onSelect: (String) -> Void
        weak var collectionView: NSCollectionView?
        var dataSource: NSCollectionViewDiffableDataSource<Section, String>?
        var lastSymbolsRevision: Int = -1

        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        func collectionView(_: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            guard let indexPath = indexPaths.first else { return }
            guard let symbolName = dataSource?.itemIdentifier(for: indexPath) else { return }
            onSelect(symbolName)
        }
    }
}

@MainActor
private final class IconCollectionViewItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("IconCollectionViewItem")

    private let iconImageView = NSImageView()
    private let checkmarkImageView = NSImageView()
    private var currentSymbolName: String?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.cornerCurve = .continuous
        view.layer?.borderWidth = 1

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageAlignment = .alignCenter
        iconImageView.imageScaling = .scaleProportionallyDown
        iconImageView.contentTintColor = .labelColor

        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.imageAlignment = .alignCenter
        checkmarkImageView.imageScaling = .scaleProportionallyDown
        checkmarkImageView.contentTintColor = .controlAccentColor
        checkmarkImageView.image = SymbolImageCache.shared.checkmarkImage
        checkmarkImageView.isHidden = true

        view.addSubview(iconImageView)
        view.addSubview(checkmarkImageView)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            checkmarkImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            checkmarkImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 12),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 12)
        ])

        updateSelectionAppearance()
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }

    func setSymbolName(_ symbolName: String) {
        guard currentSymbolName != symbolName else { return }
        currentSymbolName = symbolName

        iconImageView.image = SymbolImageCache.shared.image(for: symbolName)
        view.setAccessibilityLabel(symbolName)
        view.setAccessibilityRole(.button)
    }

    private func updateSelectionAppearance() {
        let isSelected = isSelected
        checkmarkImageView.isHidden = !isSelected

        if isSelected {
            view.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            view.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
        } else {
            view.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.2).cgColor
            view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.25).cgColor
        }
    }
}

@MainActor
private final class SymbolImageCache {
    static let shared = SymbolImageCache()

    private let cache = NSCache<NSString, NSImage>()
    let checkmarkImage: NSImage?
    private let iconSymbolConfiguration: NSImage.SymbolConfiguration
    private let log: OSLog

    private init() {
        cache.countLimit = 2048
        iconSymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "FolderBar", category: "IconPicker")
        checkmarkImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
    }

    func image(for symbolName: String) -> NSImage? {
        if let cached = cache.object(forKey: symbolName as NSString) {
            signpost(event: "symbol_cache_hit", symbolName: symbolName)
            return cached
        }

        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            signpost(event: "symbol_cache_miss_invalid", symbolName: symbolName)
            return nil
        }

        let configured = image.withSymbolConfiguration(iconSymbolConfiguration) ?? image
        configured.isTemplate = true
        cache.setObject(configured, forKey: symbolName as NSString)
        signpost(event: "symbol_cache_miss", symbolName: symbolName)
        return configured
    }

    private func signpost(event: StaticString, symbolName: String) {
        #if DEBUG
            os_signpost(.event, log: log, name: event, "%{public}s", symbolName)
        #endif
    }
}
