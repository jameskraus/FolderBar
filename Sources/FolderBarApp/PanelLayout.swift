import AppKit

enum PanelLayout {
    static let panelWidth: CGFloat = 320
    static let visibleRowCount: CGFloat = 5.5
    static let thumbnailSize: CGFloat = 48
    static let rowVerticalPadding: CGFloat = 8
    static let rowHorizontalPadding: CGFloat = 12
    static let headerHorizontalPadding: CGFloat = 12
    static let footerTrailingPadding: CGFloat = 8
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 8
    static let headerSpacing: CGFloat = 4
    static let headerHeight: CGFloat = 30
    static let footerHeight: CGFloat = 28
    static let dividerHeight: CGFloat = 1

    static var rowHeight: CGFloat {
        thumbnailSize + rowVerticalPadding * 2
    }

    static var listHeight: CGFloat {
        rowHeight * visibleRowCount
    }

    static var listContainerHeight: CGFloat {
        listHeight + dividerHeight * 2
    }

    static var contentHeight: CGFloat {
        topPadding
            + headerHeight
            + headerSpacing
            + listContainerHeight
            + footerHeight
            + bottomPadding
    }

    static var contentSize: NSSize {
        NSSize(width: panelWidth, height: contentHeight)
    }
}
