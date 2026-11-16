import Carbon.HIToolbox

// Global hotkey via Carbon: needs no Accessibility / Input Monitoring permission.
// shortcut: one hotkey only, change the key on the kVK_ANSI_P line if it clashes.
enum Hotkey {
    // A C handler cannot capture context, so the callback lives in a static.
    private static var onPress: (() -> Void)?
    private static var ref: EventHotKeyRef?

    @discardableResult
    static func register(onPress: @escaping () -> Void) -> OSStatus {
        self.onPress = onPress

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { Hotkey.onPress?() }
            return noErr
        }, 1, &spec, nil, nil)

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_P), UInt32(cmdKey | controlKey | optionKey),
            EventHotKeyID(signature: 0x71727370, id: 1),
            GetApplicationEventTarget(), 0, &ref)
        if status != noErr { NSLog("QRSnap: hotkey registration failed, status \(status)") }
        return status
    }
}
