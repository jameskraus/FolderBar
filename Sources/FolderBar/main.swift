import AppKit
import SwiftUI
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "FolderBar"
    private let logger = Logger(subsystem: AppDelegate.subsystem, category: "Lifecycle")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private lazy var panelController = MenuBarPanelController(
        statusItem: statusItem,
        rootView: AnyView(PlaceholderListView()),
        contentSize: NSSize(width: 240, height: 180)
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application finished launching")

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "FolderBar")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePanel(_:))
        }

        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application will terminate")
    }

    @objc private func togglePanel(_ sender: Any?) {
        panelController.toggle()
    }
}

struct PlaceholderListView: View {
    private let items = [
        "Example Folder A",
        "Example Folder B",
        "Example Folder C",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                Text(items[index])
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if index < items.count - 1 {
                    Divider()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
