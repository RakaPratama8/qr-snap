# PRD: Screen-Region QR Reader for macOS

Nov 15, 2026 · @Raka Pratama

## Problem Statement

Mac users who receive a QR code inside an image cannot get its link without leaving their desktop apps. Text in images already works (Quick Look and Preview let you select it); QR codes do not.

Today the user saves the image, opens a browser, finds a QR reader site, uploads the image, waits, then copies the link: about 7 steps and up to 10 seconds each time. Scanning the laptop screen with a phone avoids the website but needs a second device, which is the same friction in a different form.

**Evidence so far:** one user (the author), about 3 times a week. The cost is annoyance and context-switching, not time: roughly 20 to 30 seconds a week. This PRD treats the tool as a personal tool, not a validated product.

## Goals

Targets marked *proposed* are starting points to confirm after the first week of use.

- **Fewer steps:** from about 7 steps to 3 (press shortcut, drag over the QR code, get the link).
- **Faster:** from up to 10 seconds to under 3 seconds from shortcut press to link shown (*proposed*).
- **No website detour:** in the first 10 QR images received, at least 8 are handled with the shortcut and 0 with a website (*proposed*).
- **No network dependency:** works with Wi-Fi off, since waiting on internet speed was part of the original pain.

## Non-Goals

- **Text extraction from images.** macOS already selects text in Quick Look and Preview, so there is no gap to fill.
- **Barcode types other than QR.** Not the observed problem.
- **Other platforms** (Windows, Linux, iPhone). The need was only observed on macOS.
- **History, settings, accounts or cloud sync.** Extra surface for a personal tool with about 3 uses a week.
- **Distribution, App Store or monetization.** The problem is validated for one user only; revisit if others show the same pain.

## User Stories

**Persona: Mac user who receives QR images in chat or email (currently the author)**

1. As a Mac user, I want to press a shortcut and drag over a QR code on my screen so that I get its link without saving the image or opening a website.
2. As a Mac user, I want the decoded link copied to my clipboard and shown on screen so that I can paste or open it right away.
3. As a Mac user, I want a clear message when no QR code is found in my selection so that I know to reselect instead of wondering what happened.
4. As a Mac user, I want to cancel a selection with Esc so that pressing the shortcut by accident costs nothing.
5. As a first-time user, I want to be told why screen access is needed before macOS asks for it so that I can grant it once with confidence.

## Requirements

### Must-Have (P0)

- **Global shortcut starts region selection.** Given the tool is running, when I press the shortcut in any app, then a selection overlay appears immediately.
- **Decode QR locally.** Given a known-good QR code in the selected region, when I release the mouse, then its contents are decoded with Wi-Fi off.
- **Show and copy the result.** Given a successful decode, then the contents appear in a small popup and are on the clipboard. Non-URL contents are shown as raw text.
- **No-QR feedback.** Given a region with no QR code, then a "No QR code found" message appears and nothing is copied.
- **Cancel.** Given the overlay is open, when I press Esc, then it closes and the clipboard is unchanged.
- **Permission prompt.** Given first use, then the tool explains why screen recording access is needed before triggering the macOS prompt.

### Nice-to-Have (P1)

- Open the link in the default browser with one key press or click from the popup.
- Guidance when the QR is cut off or too small ("select the whole code").
- Launch at login.

### Future Considerations (P2)

- Other barcode types.
- Alternative inputs (clipboard image, dropped file), which were considered and passed over for v1 because they add steps.
- Scan history.

## Success Metrics

The tool counts as a success if it replaces the website detour, not if it saves time: at about 3 uses a week the time saved is small. Track with a simple tally in a notes file; no analytics needed.

| Type | Metric | Baseline | Target | How measured |
| --- | --- | --- | --- | --- |
| Leading | Time from start to link shown | Up to 10 s (website route) | Under 3 s (*proposed*) | Time 3 scans by hand |
| Leading | Steps to the link | About 7 | 3 | Count once |
| Leading | Decode success on known-good QR images | n/a | 9 of 10 (*proposed*) | Test with 10 QR images |
| Lagging | Shortcut vs website use | 0 shortcut, 10 website | 8 of 10 shortcut, 0 website (*proposed*) | Tally per QR image received |
| Lagging | Still in use after 4 weeks | n/a | Yes (*proposed*) | Self-check at week 4 |

**Drop criterion:** if the website is still used for QR codes after 4 weeks of having the tool, drop it or rethink it.

## Open Questions

**Blocking (answer before building)**

- [ ] Decided: a small native app, chosen to build app-development experience for the portfolio. (Engineering, the author)
- [ ] Proposed: Control + Option + Command + Q (three modifiers clash with other apps far less often). Check System Settings > Keyboard > Keyboard Shortcuts for conflicts before adopting. (Design, the author)

**Non-blocking**

- [ ] Decided: open the link directly, as a practice feature. Recommended safeguard: show the link first and open it with one key press, since a QR code can point to a malicious site. (Design, the author)
- [ ] Decided: yes, acceptable. The prompt appears once, after the tool explains why it is needed. (Design, the author)
- [ ] Do 3 other Mac users feel the same pain, and how often do they receive QR images? Currently the problem is validated for one user only. (User research)

## Timeline Considerations

No hard deadline or external dependency. Phasing:

1. **v1 (P0 only):** build the smallest version and use it for the next 10 QR images you receive.
2. **Week 1 check:** read the tally. At 8 of 10 or better through the shortcut, move on to P1. Below that, find out why before adding anything.
3. **Week 4 check:** if the website is still being used, apply the drop criterion.
