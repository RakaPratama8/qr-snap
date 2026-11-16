# QR Snap

A personal macOS menu bar app that reads QR codes straight off your screen. Press a shortcut, drag over a QR code, and the link is copied, shown in a popup and, for `http`/`https` links, opened in your browser. Decoding is fully local, so it works with Wi-Fi off.

Native Swift, Apple frameworks only (`Cocoa`, `Carbon.HIToolbox`, `ScreenCaptureKit`, `Vision`). No third-party libraries, about 260 lines of code.

## Usage

1. Press **Ctrl+Option+Command+Q** in any app.
2. Drag over the QR code. Press **Esc** (or drag less than 10 pt) to cancel.
3. The decoded text is copied to the clipboard and shown in a popup at the top of the screen. Click the popup or wait about 4 seconds to dismiss it.
4. If the text is an `http` or `https` URL, it also opens in the default browser.

Anything else (plain text, Wi-Fi codes, `file:`, `tel:`, `mailto:`, `javascript:` and custom schemes) is copied and shown but never opened. If the selection has no QR code, a "No QR code found" message appears and the clipboard is unchanged.

The app runs as a menu bar item with no Dock icon. The menu has **Scan QR** and **Quit**.

## Requirements

- macOS 15.2 or later
- Swift toolchain (Xcode Command Line Tools are enough; full Xcode is not needed)

## Build and run

```bash
./build.sh
open QRSnap.app
```

`build.sh` runs `swift build -c release`, assembles `QRSnap.app` with an `Info.plist` (`LSUIElement=true`) and ad-hoc signs it.

## Screen Recording permission

On the first scan the app explains why it needs screen access, then triggers the macOS prompt. Allow it, then restart the app once.

Because the app is ad-hoc signed, every rebuild changes its code signature and macOS forgets the grant. After a rebuild the app shows the explainer again instead of scanning. To re-grant:

```bash
tccutil reset ScreenCapture local.qrsnap
```

Then restart the app, press the hotkey, click Continue, allow it in the macOS prompt, and restart the app once more. Signing with a stable self-signed certificate in `build.sh` would stop this; it is not set up.

## How it works

| File | Role |
| --- | --- |
| `Sources/QRSnap/main.swift` | `NSApplication` bootstrap with the `.accessory` activation policy. |
| `Sources/QRSnap/AppDelegate.swift` | Status item and menu, hotkey registration, and the scan pipeline: access check, overlay, capture, decode, clipboard, open, popup. |
| `Sources/QRSnap/Hotkey.swift` | Global hotkey through Carbon `RegisterEventHotKey`. |
| `Sources/QRSnap/Overlay.swift` | Dim borderless window per screen and drag selection. |
| `Sources/QRSnap/Capture.swift` | Permission explainer and `SCScreenshotManager.captureImage(in:)` at native Retina size. |
| `Sources/QRSnap/QR.swift` | Vision QR decoding (`.qr` only) and the `http`/`https` open check. |
| `Sources/QRSnap/Popup.swift` | Top-center toast with the result. |

## Results

Acceptance checks against [SPEC.md](SPEC.md), recorded in [TALLY.md](TALLY.md):

- Time from shortcut press to link shown: 1.98 s, 1.06 s and 2.76 s (target under 3 s).
- Decode on 10 different QR images: 10 of 10 (target 9 of 10).
- One scan with Wi-Fi off worked.

## Out of scope

Other barcode types, scan history, settings, accounts, distribution and text extraction. See [SPEC.md](SPEC.md) for the full requirements and [PLAN.md](PLAN.md) for the implementation plan.
