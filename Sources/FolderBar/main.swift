import AppKit
import SwiftUI
import os

private let subsystem = Bundle.main.bundleIdentifier ?? "FolderBar"

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: subsystem, category: "Lifecycle")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application finished launching")

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "FolderBar")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(rootView: PlaceholderListView())

        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application will terminate")
    }

    @objc private func togglePopover(_ sender: Any?) {
        logger.debug("Toggling popover")
        guard let button = statusItem.button else {
            logger.error("Status item button missing")
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct PlaceholderListView: View {
    var body: some View {
        List {
            Text("Example Folder A")
            Text("Example Folder B")
            Text("Example Folder C")
        }
        .frame(width: 240, height: 180)
    }
}

@main
@MainActor
struct FolderBarMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
