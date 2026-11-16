import Cocoa
import ScreenCaptureKit

enum Capture {
    /// True if screen access is granted. Otherwise explains why, triggers the macOS prompt once, and returns false.
    static func ensureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "QR Snap needs Screen Recording access"
        alert.informativeText = "It reads the QR code in the region you drag, and nothing else. Nothing leaves your Mac.\n\nAfter you allow it in System Settings > Privacy & Security > Screen Recording, quit and reopen QR Snap."
        alert.addButton(withTitle: "Continue")
        alert.runModal()
        _ = CGRequestScreenCaptureAccess()
        return false
    }

    /// `rect` is in global AppKit coordinates (bottom-left origin); SCK wants top-left origin.
    static func capture(appKitRect rect: NSRect) async throws -> CGImage {
        let primaryHeight = NSScreen.screens[0].frame.height
        let flipped = CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
        return try await SCScreenshotManager.captureImage(in: flipped)
    }
}
