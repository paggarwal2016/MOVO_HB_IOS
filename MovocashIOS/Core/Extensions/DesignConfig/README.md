# MovoCash Design System — iOS

Single source of truth for the **Void Silver** brand palette. Every screen reads
from these files instead of hardcoding hex values, font sizes, or spacing.

## File overview

| File | Purpose |
|---|---|
| `DesignTokens.swift` | Raw tokens (hex, sizes, radii). Pure data. |
| `Theme.swift` | Semantic color API (`Theme.color.background`). Maps intent → palette. |
| `Typography.swift` | Font scale (`Typography.heroTitle`). Drives Dynamic Type. |
| `Spacing.swift` | Spacing & radius scales (`Spacing.cardPadding`, `Radius.button`). |
| `Theme+Modifiers.swift` | View modifiers, `Color.movo.*` shortcuts, button styles. |

## Drop-in setup

1. Copy these 5 files into a `DesignSystem/` folder in the project.
2. Make sure `DesignSystem/` is part of the target (Xcode → Target Membership).
3. (Optional) If you ship a custom font, register `.otf` in `Info.plist` under
   `UIAppFonts` and set `FontFamily.active = .custom(...)` in `App.swift`.

## Usage (from any view)

```swift
import SwiftUI

struct DashboardCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow("Available balance")
            Text("$50.00")
                .textStyle(Typography.balance)
                .foregroundColor(Color.movo.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCard(gradientFrom: .topLeft)
        .padding(.horizontal, Spacing.screenHorizontal)
    }
}
```

## Buttons

```swift
Button("Transfer") { transfer() }
    .buttonStyle(MovoPrimaryButtonStyle())     // big pill CTA

Button("Cancel") { dismiss() }
    .buttonStyle(MovoSecondaryButtonStyle())   // neutral pill

Button("View receipt") { showReceipt() }
    .buttonStyle(MovoTextButtonStyle())        // text-only, accent color
```

## Status pills

```swift
StatusPill("Recommended", variant: .accent)
StatusPill("Completed",  variant: .success, icon: "checkmark")
StatusPill("Pending",    variant: .neutral)
StatusPill("Failed",     variant: .danger,  icon: "xmark")
StatusPill("On Movo",    variant: .accent)
```

## Re-skinning

The whole app re-skins by editing **two places**:

- `DesignTokens.Palette.*` — change the hex values
- `Theme.color = .voidSilver` (or any future `ColorScheme`)

No view code needs to be touched.

## Adding a new semantic intent

If you find yourself reaching for a raw token in a view (`DesignTokens.Palette.foo`),
that's a signal to add a new semantic name to `ColorScheme` so the intent stays
documented and re-skinnable.

## Conventions

- **Always** use `Color.movo.*` in views, never raw hex.
- **Always** use `Typography.*` styles via `.textStyle(...)`. No `.font(.system(...))`.
- **Always** use `Spacing.*` / `Radius.*` for layout numbers. No magic numbers.
- Screen-level top padding/horizontal margins use `Spacing.screenHorizontal`.
