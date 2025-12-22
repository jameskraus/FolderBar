import AppKit
import SwiftUI

@MainActor
final class MenuBarPanelController: NSObject {
    private let statusItem: NSStatusItem
    private let panel: MenuBarPanel
    private let hostingController: NSHostingController<AnyView>
    private let verticalOffset: CGFloat = 6
    private let onShow: (() -> Void)?

    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?

    init(
        statusItem: NSStatusItem,
        rootView: AnyView,
        contentSize: NSSize,
        onShow: (() -> Void)? = nil
    ) {
        self.statusItem = statusItem
        self.hostingController = NSHostingController(rootView: rootView)
        self.onShow = onShow

        let styleMask: NSWindow.StyleMask = [
            .titled,
            .fullSizeContentView,
        ]

        self.panel = MenuBarPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: true
        )

        super.init()

        panel.contentViewController = hostingController
        panel.setContentSize(contentSize)

        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.isOpaque = true
        panel.hasShadow = true

        panel.level = .popUpMenu
        panel.collectionBehavior = [
            .moveToActiveSpace,
            .transient,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]

        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.tabbingMode = .disallowed
        panel.animationBehavior = .none
    }

    func toggle() {
        if panel.isVisible {
            close()
        } else {
            show()
        }
    }

    func show() {
        guard let button = statusItem.button else { return }
        positionPanel(relativeTo: button)

        button.state = .on
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        onShow?()
        installMonitors()
    }

    func close() {
        panel.orderOut(nil)
        statusItem.button?.state = .off
        removeMonitors()
    }

    private func positionPanel(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }

        let rectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = buttonWindow.convertToScreen(rectInWindow)
        let screen = buttonWindow.screen
            ?? NSScreen.screens.first(where: { $0.frame.intersects(buttonRectOnScreen) })
        guard let screen else { return }

        let visible = screen.visibleFrame
        let scale = screen.backingScaleFactor
        let panelSize = panel.frame.size

        var x = buttonRectOnScreen.midX - panelSize.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - panelSize.width - 8)

        let topY = buttonRectOnScreen.minY - verticalOffset
        var y = topY - panelSize.height
        if y < visible.minY + 8 {
            y = visible.minY + 8
        }

        x = round(x * scale) / scale
        y = round(y * scale) / scale

        panel.setFrame(
            NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height),
            display: false
        )
    }

    private func installMonitors() {
        removeMonitors()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self else { return }

            let mouse = NSEvent.mouseLocation
            if self.panel.frame.contains(mouse) { return }

            if let button = self.statusItem.button,
               let window = button.window {
                let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
                if rect.contains(mouse) { return }
            }

            self.close()
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 {
                self.close()
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        globalMouseMonitor = nil
        localKeyMonitor = nil
    }
}

final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
