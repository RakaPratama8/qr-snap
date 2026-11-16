# PLAN: QR Snap — macOS menu bar QR reader

Source: [SPEC.md](SPEC.md). Native Swift, no third-party libraries, no Xcode project (this Mac has Command Line Tools only; `xcodebuild` does not work, `swift build` does).

## Primary goal

Press one shortcut anywhere on the Mac, drag over a QR code on screen, and the link opens in the browser within 3 seconds, with Wi-Fi off and no website detour.

## Decisions taken from SPEC.md / the request

- **Hotkey:** Control+Option+Command+Q (SPEC proposal). Menu bar item "Scan QR" is the fallback if it clashes.
- **Open link directly** (your instruction; SPEC's "show first" safeguard is the open question you already decided). Two guards kept because they cost ~3 lines: only `http`/`https` open automatically (a QR with `file:` or a custom scheme is shown as text only), and the link is always shown in the popup and copied to the clipboard.
- Non-URL contents: shown as raw text, copied, not opened.
- Out of scope (SPEC non-goals / P1+): other barcode types, history, settings, launch at login, "QR too small" guidance, App Store signing.

## Phase 0: Documentation discovery (DONE, results below)

**How this serves the primary goal:** it fixes the exact Apple APIs up front, so later phases copy known-good calls instead of guessing at ones that were removed from macOS.

Verified on this machine (macOS 27.0.1, Swift 6.4, SDK at `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`) by reading headers and compiling probes:

### Allowed APIs

| Need | API | Source / evidence |
| --- | --- | --- |
| Menu bar item | `NSStatusBar.system.statusItem(withLength:)`, `NSApp.setActivationPolicy(.accessory)` | AppKit |
| Global hotkey, no extra permission | Carbon `InstallEventHandler` + `RegisterEventHotKey(UInt32(kVK_ANSI_Q), UInt32(cmdKey\|controlKey\|optionKey), EventHotKeyID, GetApplicationEventTarget(), 0, &ref)` with `EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))` | `Carbon.framework/.../HIToolbox.framework/Headers/Events.h` lines 123-127, 208. Probe compiled and returned status 0 |
| Permission check / prompt | `CGPreflightScreenCaptureAccess()`, `CGRequestScreenCaptureAccess()` | `CoreGraphics.framework/Headers/CGWindow.h` lines 295-308. A previously denied process is never re-prompted |
| Capture a region | `SCScreenshotManager.captureImage(in: CGRect, completionHandler:)` (Swift also gets an `async throws` form), macOS 15.2+. Rect is in points, global display space, works across displays | `ScreenCaptureKit.framework/Headers/SCScreenshotManager.h` lines 154-161 |
| Decode QR | `VNDetectBarcodesRequest()`, `request.symbologies = [.qr]`, `VNImageRequestHandler(cgImage:options:)`, `try handler.perform([request])`, `request.results` as `VNBarcodeObservation`, `.payloadStringValue` (optional String) | `Vision.framework/Headers/VNDetectBarcodesRequest.h`, `VNObservation.h:432`, `VNTypes.h:67`. The `symbologies = [.qr]` line compiled |
| Open link | `NSWorkspace.shared.open(URL)` | AppKit |
| Clipboard | `NSPasteboard.general.clearContents()` then `setString(_, forType: .string)` | AppKit |

### Anti-patterns (do not use)

- `CGWindowListCreateImage` is **obsoleted since macOS 15** (`SCREEN_CAPTURE_OBSOLETE(10.5,14.0,15.0)` in `CGWindow.h`). Will not compile or run. Same for `CGDisplayCreateImage`.
- Do not use `NSEvent.addGlobalMonitorForEvents` for the hotkey (needs Input Monitoring / Accessibility permission).
- Do not set a Vision request `revision` (default is the latest; Revision 1 and 2 are deprecated).
- Do not import anything outside Apple frameworks: allowed imports are `Cocoa`, `Carbon.HIToolbox`, `ScreenCaptureKit`, `Vision`.
- Do not assume the capture rect's origin. NSScreen uses a bottom-left origin; the SCK rect convention is only documented as "display space". Phase 4 proves it with a saved PNG before anything depends on it.

### Layout (created across phases)

```
Package.swift                 // swift-tools 5.9, macOS 15.2 minimum, one executableTarget "QRSnap"
Sources/QRSnap/main.swift     // NSApplication bootstrap
Sources/QRSnap/AppDelegate.swift   // status item, menu, wiring
Sources/QRSnap/Hotkey.swift
Sources/QRSnap/Overlay.swift       // drag-select window
Sources/QRSnap/Capture.swift       // permission + SCK
Sources/QRSnap/QR.swift            // Vision decode
Sources/QRSnap/Popup.swift         // result toast
build.sh                      // swift build, assemble QRSnap.app, ad-hoc codesign
```

### Known risk: screen permission resets after rebuilds

`build.sh` ad-hoc signs (`codesign --force --sign - QRSnap.app`). Each rebuild changes the signature, so macOS may forget the Screen Recording grant and you re-grant it in System Settings. Annoying but harmless. If it gets old: create a self-signed "Code Signing" certificate once in Keychain Access and pass its name to `codesign --sign`. Not done in this plan.

---

## Phase 1: Menu bar app that builds and quits

**How this serves the primary goal:** nothing else can be tested until there is a runnable app that lives in the menu bar without a Dock icon, and a repeatable way to build it.

**Implement**
- `Package.swift` (probe that built fine here: `// swift-tools-version:5.9`, `platforms: [.macOS("15.2")]` or `.v15` if the string form is rejected, one `.executableTarget(name: "QRSnap", path: "Sources/QRSnap")`).
- `main.swift`: `let app = NSApplication.shared; app.setActivationPolicy(.accessory); let d = AppDelegate(); app.delegate = d; app.run()`.
- `AppDelegate`: `NSStatusItem` with SF Symbol `qrcode.viewfinder`, menu with "Scan QR" (does nothing yet, `NSSound.beep()`) and "Quit" (`NSApp.terminate`).
- `build.sh`: `swift build -c release`, create `QRSnap.app/Contents/{MacOS,Info.plist}`, copy binary, Info.plist with `CFBundleIdentifier=local.qrsnap`, `CFBundleName`, `CFBundleExecutable`, `LSUIElement=true`, `LSMinimumSystemVersion`, then ad-hoc codesign.

**Test yourself**
```bash
./build.sh && open QRSnap.app
```
- A QR icon appears in the menu bar; no Dock icon; "Quit" removes it.

**Verify:** `grep -rn "^import" Sources` shows only Apple frameworks.
**Guard:** do not add an Xcode project, storyboard, or SwiftUI. `LSUIElement` must be in the bundle Info.plist (running the bare binary from `.build/` will show a Dock icon; always test via `open QRSnap.app`).

## Phase 2: Global shortcut

**How this serves the primary goal:** "press a shortcut in any app" is the entry point of the whole flow; it must work while another app is in front.

**Implement** (copy the probe pattern from Phase 0 table)
- `Hotkey.swift`: `InstallEventHandler` + `RegisterEventHotKey` for Control+Option+Command+Q. The C handler calls a Swift closure stored in a static (a C function pointer cannot capture), dispatching to the main queue. Check the returned status and log it if not 0.
- `AppDelegate`: register at launch; the hotkey and the "Scan QR" menu item both call `startScan()` (still just `NSSound.beep()`).

**Test yourself:** open Safari/Notes, press ⌃⌥⌘Q: you hear the beep. If silent and status was non-zero, another app owns the combo; pick another key in the one `kVK_ANSI_Q` line. Also check System Settings > Keyboard > Keyboard Shortcuts for a conflict (system shortcuts can swallow the key silently).

**Guard:** no Accessibility/Input Monitoring permission should be requested at any point.

## Phase 3: Drag-select overlay with Esc to cancel

**How this serves the primary goal:** "drag over the QR code" and "cancel with Esc" are the two interaction stories (3 steps, accidental press costs nothing).

**Implement**
- `Overlay.swift`: for each `NSScreen.screens` one borderless `NSWindow` subclass (`canBecomeKey` / `canBecomeMain` return true), `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, `backgroundColor` black at ~0.2 alpha, `isOpaque = false`. Content view: `NSView` with `resetCursorRects` crosshair, `mouseDown` / `mouseDragged` / `mouseUp` drawing a stroked selection rectangle, `keyDown` with `event.keyCode == 53` (Esc) to cancel. Call `NSApp.activate()` and `makeKeyAndOrderFront` so Esc is delivered (the app is `.accessory`).
- Overlay API: `func selectRegion(completion: (CGRect?) -> Void)`; `nil` on Esc or a click without drag (selection under ~10 pt counts as cancel). Close all overlay windows before calling completion.
- `startScan()` shows the overlay and `print`s the rect (NSLog) for now.

**Test yourself:** press ⌃⌥⌘Q, screen dims with crosshair; drag draws a box; release closes the overlay and logs a rect; Esc closes it and logs nothing. Try with a second monitor if you have one, and while a full-screen app is in front.

**Guard:** do not use `NSEvent` global monitors for Esc (the overlay window is key, so a normal `keyDown` works).

## Phase 4: Screen permission explainer + region capture

**How this serves the primary goal:** getting pixels is the one step that needs a macOS permission; the SPEC requires explaining it before the system prompt, and the capture rect must be correct or decode will fail for confusing reasons.

**Implement**
- `Capture.swift`:
  - `ensureAccess()`: if `CGPreflightScreenCaptureAccess()` is true, proceed. Otherwise show an `NSAlert` ("QR Snap needs Screen Recording access to read the QR code you select. It only looks at the region you drag. Nothing leaves your Mac.") with a Continue button, then call `CGRequestScreenCaptureAccess()` and abort this scan. After granting, macOS usually needs the app restarted: say so in the alert ("then quit and reopen QR Snap").
  - `capture(rect:) async throws -> CGImage`: `try await SCScreenshotManager.captureImage(in: rect)`. If the async overload does not compile, use the completion-handler form from the Phase 0 table with a `CheckedContinuation`.
  - Convert the overlay's rect from AppKit (bottom-left origin) to display space (top-left origin): `y = primaryScreenHeight - rect.maxY`, where primary is `NSScreen.screens[0]`.
- Order matters: close overlay windows, then wait one runloop tick plus ~100 ms so the dim layer is not in the screenshot, then capture.
- **Temporary debug line:** write the `CGImage` to `/tmp/qrsnap-debug.png` (remove in Phase 6).

**Test yourself:** first run shows your explanation, then the macOS prompt; grant in System Settings > Privacy & Security > Screen Recording, restart the app. Scan a region, then `open /tmp/qrsnap-debug.png`: it must be exactly the region you dragged, not dimmed, not offset or flipped. Test with the window on the primary display and, if you have one, a second display. Check the PNG's pixel size: on a Retina screen it should be about 2x the dragged points. If the image is offset or flipped, fix the Y conversion before moving on.

**Guard:** never call `CGWindowListCreateImage`. Do not capture the full screen and crop it yourself unless `captureImage(in:)` proves wrong in the test above.

## Phase 5: Decode QR with Vision

**How this serves the primary goal:** this is the core promise: turn pixels into the link, locally and offline.

**Implement**
- `QR.swift`: `func decodeQR(_ image: CGImage) -> String?`: `let req = VNDetectBarcodesRequest(); req.symbologies = [.qr]; try VNImageRequestHandler(cgImage: image, options: [:]).perform([req]); return (req.results?.first)?.payloadStringValue`. Return nil on no result or thrown error.
- `startScan()` pipeline: overlay → ensureAccess → capture → decode → `print` the string or "No QR code found".

**Test yourself:** turn Wi-Fi off. Scan 10 different QR images (chat screenshots, a QR on a web page, dark mode QR, a small one). SPEC target: 9 of 10 decode. Scan a region with no QR: logs "No QR code found".

**Guard:** do not add upscaling, retries, or other symbologies now. If a small QR fails, that is a P1 item ("select the whole code"); note which images failed for the week-1 check.

## Phase 6: Result popup, clipboard, open link

**How this serves the primary goal:** this is the visible payoff: link on screen, on the clipboard, and opened, plus a clear message when nothing was found.

**Implement**
- `Popup.swift`: small borderless `NSPanel` (non-activating, `level = .floating`) near the top-center of the screen under the cursor, rounded dark background, one text label, auto-dismiss after ~4 s or on click. Used for both results and "No QR code found".
- On success: set clipboard to the string; show it in the popup; if `URL(string:)` parses with scheme `http` or `https`, `NSWorkspace.shared.open(url)`. Otherwise just show raw text.
- On no QR: popup "No QR code found"; clipboard untouched.
- Delete the Phase 4 debug PNG write.

**Test yourself:** scan a URL QR: browser opens, popup shows the link, ⌘V pastes it. Scan a QR containing plain text (e.g. made from "hello"): popup shows "hello", copied, nothing opens. Scan a Wi-Fi/`file:` style QR: shown, not opened. Scan empty area: "No QR code found", clipboard unchanged (copy something else first and paste to check). Esc during selection: clipboard unchanged.

**Guard:** `payloadStringValue` is optional; do not force-unwrap. Do not open non-http(s) schemes.

## Phase 7 (final): Verification against SPEC

**How this serves the primary goal:** proves the tool meets the numbers in SPEC.md, not just that it compiles.

- **Anti-pattern greps** (should print nothing):
  ```bash
  grep -rnE "CGWindowListCreateImage|CGDisplayCreateImage|addGlobalMonitorForEvents|VNDetectBarcodesRequestRevision" Sources
  grep -rhE "^import" Sources | sort -u   # only Cocoa, Carbon.HIToolbox, ScreenCaptureKit, Vision
  ls /tmp/qrsnap-debug.png                # should not be written any more
  ```
- **SPEC P0 checklist:** shortcut from any app; decode with Wi-Fi off; popup + clipboard; "No QR code found"; Esc cancels with clipboard unchanged; permission explained before the macOS prompt.
- **SPEC numbers:** time 3 scans by hand from shortcut press to link shown (target under 3 s); 10-image decode test (target 9/10); 3 steps total.
- **Then** start the SPEC's real test: use it for the next 10 QR images you receive and keep the tally in a notes file (Week 1 and Week 4 checks are in SPEC.md).
