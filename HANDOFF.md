# Handoff

> Generated: 2026-11-16
> Project: /Users/Raka/Projects/qr-snap (QR Snap, macOS menu bar app)
> Session summary: Planned and built phases 1-7 of a native Swift QR screen reader; all code is done, only the user's manual acceptance checks remain.

## Goal

A personal macOS menu bar app: press Ctrl+Option+Command+Q anywhere, drag over a QR code on screen, and within 3 seconds the link is copied, shown in a popup and (for http/https) opened in the browser, with Wi-Fi off. Native Swift, Apple frameworks only, no third-party libraries. Source of truth: `SPEC.md` (PRD) and `PLAN.md` (7-phase plan with verified Apple APIs).

## Current State

**Working (verified by me):**
- Clean `./build.sh` succeeds with no warnings; the app is ad-hoc signed, `LSUIElement=true`.
- Phase 3 overlay: the user's log showed one drag rect and one Esc cancel.
- Phase 4 capture: `/tmp/qrsnap-debug.png` was a crisp, undimmed, unflipped crop at native Retina size (1538x604 px for ~769x302 pt). User confirmed it matched their selection.
- Phase 5 decode: two real scans of the same on-screen QR returned `https://myqrcode.mobi/40813b5a`. Generated URL/text/Wi-Fi QR codes decode in a scratch test; a blank image returns nil.
- `openableURL` rejects `file:`, `tel:`, `javascript:`, `mailto:`, custom schemes, bare `https:`, plain text (scratch test with asserts live).
- Greps clean: no `CGWindowListCreateImage`, no global key monitors, no network APIs, no debug files. Imports are only `Cocoa`, `Carbon.HIToolbox`, `ScreenCaptureKit`, `Vision`. About 260 lines total.

**Not verified by me (user did these by hand, I did not see them):**
- Phase 6 popup, clipboard copy and browser opening. The user answered "Yes" to the Phase 6 checks.
- SPEC numbers: time under 3 s, decode 9 of 10 on known-good images, Wi-Fi-off run. These are still open (see Next Steps).

**Broken:** nothing known. Recurring annoyance, not a bug: every rebuild changes the ad-hoc signature, macOS drops the Screen Recording grant, and the app logs/aborts with "no screen access" until re-granted. The last clean rebuild (Phase 7) reset the grant again, and the running process is the older binary.

## Files in Play

| File | Why It Matters |
|------|---------------|
| `SPEC.md` | The PRD: P0 requirements, success metrics, week-1 and week-4 checks. |
| `PLAN.md` | The phased plan, the verified Allowed APIs table and the anti-pattern list. |
| `Package.swift` | SwiftPM, one executable target `QRSnap`, macOS 15.2 minimum. |
| `build.sh` | `swift build -c release`, assembles `QRSnap.app` with Info.plist, ad-hoc codesigns. |
| `Sources/QRSnap/main.swift` | NSApplication bootstrap, `.accessory` activation policy. |
| `Sources/QRSnap/AppDelegate.swift` | Status item and menu, registers the hotkey, `startScan()` pipeline: access check, overlay, 150 ms wait, capture, decode, clipboard, open, popup. |
| `Sources/QRSnap/Hotkey.swift` | Carbon `RegisterEventHotKey` for Ctrl+Opt+Cmd+Q (`kVK_ANSI_Q`). The one remaining `NSLog` is here (registration failure). |
| `Sources/QRSnap/Overlay.swift` | Borderless dim window per screen, drag selection, Esc (keyCode 53) cancels, drags under 10 pt count as cancel. Returns the rect in AppKit global coordinates. |
| `Sources/QRSnap/Capture.swift` | Permission explainer plus `SCScreenshotManager.captureImage(in:)`. Flips Y with `NSScreen.screens[0].frame.height - rect.maxY`. |
| `Sources/QRSnap/QR.swift` | `decodeQR` (Vision, `.qr` only) and `openableURL` (http/https only). |
| `Sources/QRSnap/Popup.swift` | Top-center dark toast, click or ~4 s dismiss. |
| `TALLY.md` | Template for the timing, 10-image decode and real-use tally. |

## What Has Been Tried (and Why It Failed)

### Attempt 1: NSLog for placeholder output
- **What:** Logged the selected region with `NSLog`, read it with `log show` and `log stream`.
- **Why it failed:** The unified log was flooded with unrelated xpc/LaunchServices debug lines and the NSLog line never showed up reliably, so I could not tell whether the overlay fired. Fixed by appending to `/tmp/qrsnap.log` instead; later removed in Phase 6. Do not go back to NSLog for debugging this app; use a file or the popup.

### Attempt 2: Simulating the hotkey from the shell
- **What:** `osascript ... key code 12 using {control, option, command}` to press the shortcut.
- **Why it failed:** `osascript is not allowed to send keystrokes (1002)`. Scripted input needs Accessibility permission, which I must not grant or work around. The hotkey and overlay can only be tested by the user.

### Attempt 3: Decoder self-check compiled with `-O`
- **What:** Ran the scratch QR test built with `swiftc -O`.
- **Why it failed:** `-O` strips `assert`, so the "ok" prints proved nothing. Rebuilt without `-O` and added a negative control (a wrong expectation) that crashed with exit 133, proving the asserts run. A first negative-control attempt failed to compile because top-level code must live in `main.swift`. Any scratch test must be built without `-O`.

### Attempt 4: "no screen access" after rebuilds
- **What:** Rebuilt and relaunched, expecting the previous Screen Recording grant to hold.
- **Why it failed:** `build.sh` ad-hoc signs, so each rebuild changes the code signature and TCC forgets the grant. `CGPreflightScreenCaptureAccess()` returns false and `startScan()` shows the explainer and stops. Fix is the user running `tccutil reset ScreenCapture local.qrsnap`, restarting the app, pressing the hotkey, clicking Continue, allowing it in the macOS prompt (or System Settings), then restarting once more. I do not run `tccutil` myself because it changes privacy settings.

## Current Best Theory

The implementation is complete and matches the plan. The only open question is empirical: does it meet the SPEC numbers (under 3 s, 9 of 10 decode, works offline) on the user's own QR images. Likely failure mode if any scans fail: small or low-contrast QR codes, which SPEC treats as a P1 item ("select the whole code" guidance), not a v1 fix.

## Next Steps

1. Ask the user whether the permission has been re-granted since the last clean rebuild. If not, walk them through the `tccutil reset ScreenCapture local.qrsnap` flow above.
2. Have the user time 3 scans (hotkey press to link shown), scan 10 different QR images (chat screenshot, web page, dark mode, small, plain-text, a Wi-Fi/`file:` style one), and repeat one scan with Wi-Fi off. They record results in `TALLY.md`.
3. If any decode fails: collect what kind of image it was before changing code. Do not add upscaling, retries or other symbologies unless the user asks.
4. Week-1 check (SPEC): 8 of 10 through the shortcut or better, then consider P1 (open-on-keypress safeguard, "select the whole code" hint, launch at login). Below that, find out why first.
5. Optional, only if the user wants it: stable signing in `build.sh` via a self-signed code-signing certificate in Keychain, to stop the grant resetting on rebuilds.

## Key Constraints

- Apple frameworks only; no third-party libraries. No Xcode on this machine (Command Line Tools only), so use `swift build` and `build.sh`, never `xcodebuild`.
- The user chose "open the link directly" over SPEC's show-first safeguard. Guards kept: only http/https opens automatically, and the text is always shown and copied.
- Do not use `CGWindowListCreateImage`/`CGDisplayCreateImage` (obsolete on macOS 15+), global key monitors for the hotkey, or Vision request revisions.
- Never grant or change macOS privacy settings on the user's behalf; direct them to do it.
- Out of scope per SPEC: other barcode types, history, settings, accounts, distribution, text extraction.
- The user relays results by running commands in the terminal pane rather than describing what they see, so ask for one concrete observation at a time or make failures visible in a file or popup.

## Memory Pointers

Skipped: claude-mem search tools were not loaded in this session.
