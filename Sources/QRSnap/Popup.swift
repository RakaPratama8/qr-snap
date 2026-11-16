import Cocoa

private final class ClickPanel: NSPanel {
    override func mouseDown(with event: NSEvent) { Popup.dismiss() }
}

/// Small dark toast at the top-center of the screen under the cursor. Click or wait ~4 s to dismiss.
enum Popup {
    private static var panel: NSPanel?
    private static var timer: Timer?

    static func show(_ text: String) {
        dismiss()

        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.maximumNumberOfLines = 3
        label.lineBreakMode = .byTruncatingMiddle
        label.preferredMaxLayoutWidth = 420
        let textSize = label.intrinsicContentSize

        let pad: CGFloat = 16
        let size = NSSize(width: textSize.width + 2 * pad, height: textSize.height + 2 * pad)
        let box = NSView(frame: NSRect(origin: .zero, size: size))
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        box.layer?.cornerRadius = 12
        label.frame = NSRect(x: pad, y: pad, width: textSize.width, height: textSize.height)
        box.addSubview(label)

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let origin = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - 80 - size.height)
        let p = ClickPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.contentView = box
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.orderFrontRegardless()
        panel = p
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in dismiss() }
    }

    static func dismiss() {
        timer?.invalidate(); timer = nil
        panel?.orderOut(nil); panel = nil
    }
}
