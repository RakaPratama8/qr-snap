import Cocoa

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionView: NSView {
    /// Called once: selection in global AppKit screen coordinates (bottom-left origin), or nil on cancel.
    var onDone: ((NSRect?) -> Void)?
    private var start: NSPoint?
    private var current: NSPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    private var selection: NSRect? {
        guard let a = start, let b = current else { return nil }
        return NSRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func point(_ event: NSEvent) -> NSPoint {
        let p = convert(event.locationInWindow, from: nil)
        return NSPoint(x: min(max(p.x, 0), bounds.width), y: min(max(p.y, 0), bounds.height))
    }

    override func mouseDown(with event: NSEvent) {
        start = point(event); current = start; needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = point(event); needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = point(event)
        guard let r = selection, r.width >= 10, r.height >= 10, let window else { onDone?(nil); return }
        onDone?(window.convertToScreen(convert(r, to: nil)))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onDone?(nil) } // Esc
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()
        guard let r = selection else { return }
        NSGraphicsContext.current?.compositingOperation = .clear
        r.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: r)
        path.lineWidth = 1
        path.stroke()
    }
}

enum Overlay {
    private static var windows: [NSWindow] = []

    /// Dims every screen; completes with the dragged rect (global AppKit coords) or nil on Esc / tiny drag.
    static func selectRegion(completion: @escaping (NSRect?) -> Void) {
        guard windows.isEmpty else { return } // hotkey pressed while already selecting

        func finish(_ rect: NSRect?) {
            guard !windows.isEmpty else { return }
            windows.forEach { $0.orderOut(nil) }
            windows = []
            completion(rect)
        }

        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onDone = finish
            window.contentView = view
            windows.append(window)
        }

        NSApp.activate()
        let underCursor = NSScreen.screens.firstIndex { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? 0
        for (i, w) in windows.enumerated() where i != underCursor { w.orderFrontRegardless() }
        windows[underCursor].makeKeyAndOrderFront(nil)
        windows[underCursor].makeFirstResponder(windows[underCursor].contentView)
    }
}
