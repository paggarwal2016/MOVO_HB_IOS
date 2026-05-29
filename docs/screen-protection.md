# Screen Protection (Screenshots, Recording, App Switcher)

## Purpose
Prevent sensitive financial data from leaking through screen captures. The app
applies two layers of protection across **every screen**, wired once at the app
root.

## What it does

| Threat | Defense | Result |
|--------|---------|--------|
| Screenshot | Secure-field canvas (Layer 1) | Captured image is black for the protected hierarchy |
| Screen / AirPlay recording | Secure-field canvas (Layer 1) + shield window (Layer 2) | Recording shows black / shield |
| App switcher snapshot | Shield window (Layer 2) | Switcher shows a "Screen Protected" cover |

## High-level design

Both layers are applied **once** in `MovocashIOSApp.swift`, so all screens are
covered automatically — there is no per-screen wiring to maintain:

```swift
RootView(kycVM: kycVM)
    ...
    .sensitiveScreen() // Layer 2
    .secured()         // Layer 1
```

### Layer 1 — Secure-field prevention (`SecureContainerView.swift`)
- iOS excludes a `UITextField`'s secure-entry canvas from screenshots and
  recordings. `.secured()` adds a tiny transparent **background marker**; once on
  screen, the marker inserts that secure canvas as an intermediate layer inside
  its host and moves the existing content into it. Captured pixels come out black.
- **It does NOT re-host the content** in a new `UIHostingController`. Re-hosting
  would sever the SwiftUI environment — breaking `@Environment(\.dismiss)` (sheet
  close buttons) and crashing views that use `@EnvironmentObject`. Because the
  content stays in its original hosting controller, dismiss, environment objects,
  focus/keyboard, sheet detents, and safe area all keep working.
- The canvas is pinned at the host's origin and fills it, so moved subviews keep
  their exact coordinates — SwiftUI's frame math is unaffected.
- **Safe fallback:** if the private secure canvas can't be located on a future
  iOS, nothing is reparented and content renders normally (no blanking, no
  breakage).

### Layer 2 — Shield & detection (`ScreenSecurityManager` + `SecureWindowShield`)
- `ScreenSecurityManager` observes `UIScreen.capturedDidChange`,
  `didEnterBackground`/`willEnterForeground`, and `userDidTakeScreenshot`.
- `SecureWindowShield` shows `ShieldView` in a top-level window (`.alert + 1`)
  during screen recording and app backgrounding (app-switcher privacy).
- Applying `.sensitiveScreen()` at the root both activates protection globally
  and instantiates the manager (registering its observers).

#### Why `didEnterBackground`, not `willResignActive`
`willResignActive` fires for **any** system overlay — Face ID, passkey sheets,
Apple Wallet, Control Center, the notification pull-down, incoming calls — not
just real backgrounding. Triggering the shield there caused it to flash on top
of every one of those prompts. `didEnterBackground` fires **only** on genuine
backgrounding (home / app switcher) and still occurs before the task-switcher
snapshot is taken, so the snapshot stays protected (Apple Tech Q&A QA1838).
This is the root-cause fix: it removes the flash for all system overlays without
any per-prompt special-casing.

## Manual suspension (reference counted)
The `didEnterBackground` trigger above already excludes all in-process system
overlays (Face ID, passkey, Apple Wallet, etc.), so individual prompts need no
special handling. A reference-counted manual suspension remains for flows that
want the shield fully off even on real backgrounding / recording:

- API: `ScreenSecurityManager.beginProtectionSuspension()` /
  `endProtectionSuspension()`. The shield resumes only when the count returns to
  zero, so overlapping suspensions are safe.
- **Only consumer: the KYC SDK** (`KYCManager`, own `UIWindow`). Suspended while
  the KYC window is alive; restored in `tearDownKYCWindow()` (both success and
  failure paths).

## Key files
- `MovocashIOS/Core/Security/SecureContainerView.swift` — Layer 1 (new)
- `MovocashIOS/Core/Security/ScreenSecurityManager.swift` — Layer 2 brain
- `MovocashIOS/Features/Shield/SecureWindowShield.swift` — Layer 2 shield window
- `MovocashIOS/Features/Shield/ShieldView.swift` — shield UI + `.sensitiveScreen()`
- `MovocashIOS/App/MovocashIOSApp.swift` — applies both layers at the root
- `MovocashIOS/KYC/Components/KYCManager.swift` — suspends protection during KYC

## Sheets & full-screen covers
SwiftUI `.sheet` / `.fullScreenCover` present in a separate context, so the root
`.secured()` does **not** cover them in screenshots. Each sensitive sheet
therefore applies `.secured()` to its own content, placed as the **first**
modifier on the content view (before any `.presentation*` modifiers, so the
sheet still reads detents / drag indicator / background). When the content is a
`switch`/`if let`, wrap it in a `Group` and apply `.secured()` to the group.

Secured sheets/covers include: create cash card, account & card details, all
transfer/funding/confirmation flows, transaction lists, bank-account linking,
PIN input alert, and passcode/biometric settings. Non-sensitive presentations
(filter pickers, contact pickers, info/help screens) are intentionally left
unsecured.

## Known limitations
- **New sheets must opt in.** Any newly added sheet/cover showing sensitive data
  must apply `.secured()` itself — there is no global hook for presented modals.
  (Layer 2's shield still covers all modals during recording / backgrounding.)
- **KYC flow is intentionally unprotected** while active (see above). A screen
  recording started during KYC will not be blanked.
- **Simulator does not reproduce capture blanking.** Verify on a real device.
- The secure-canvas technique uses a private view name; it can break on a future
  iOS. The fallback keeps the app functional if so.

## Verification
1. Build: `xcodebuild ... -sdk iphonesimulator` (clean build).
2. On a real device:
   - Screenshot a balance/card screen → image is black.
   - Start a screen recording → shield / black appears.
   - Background the app → app switcher shows the shield cover.
   - Run the KYC flow → camera and SDK screens display normally (no black).
