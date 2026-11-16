import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: "QR Snap")

        let menu = NSMenu()
        let scan = NSMenuItem(title: "Scan QR", action: #selector(startScan), keyEquivalent: "")
        scan.target = self
        menu.addItem(scan)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        Hotkey.register { [weak self] in self?.startScan() }
    }

    @objc func startScan() {
        guard Capture.ensureAccess() else { return }
        Overlay.selectRegion { rect in
            guard let rect else { return }
            Task { @MainActor in
                // Let the dim layer disappear before the screenshot.
                try? await Task.sleep(for: .milliseconds(150))
                do {
                    let image = try await Capture.capture(appKitRect: rect)
                    guard let text = decodeQR(image) else { Popup.show("No QR code found"); return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    if let url = openableURL(text) { NSWorkspace.shared.open(url) }
                    Popup.show(text)
                } catch {
                    Popup.show("Could not capture the screen: \(error.localizedDescription)")
                }
            }
        }
    }
}
