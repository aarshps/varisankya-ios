# Screenshots spec

Apple requires App Store screenshots in specific sizes for **each device
class** you support. The 6.7" set covers iPhone 16 Pro Max and is the
**minimum** required.

## Required sizes

| Device class | Resolution | When required |
| --- | --- | --- |
| 6.9" iPhone (iPhone 16 Pro Max) | 1320 × 2868 | Required |
| 6.5" iPhone (iPhone 11 Pro Max / XS Max) | 1284 × 2778 *(or 1242 × 2688)* | Required if 6.7" not supplied — easier to just provide 6.7" |
| 6.1" iPhone (iPhone 16 / 15) | 1179 × 2556 | Optional but recommended |

For each size, supply **3–10 screenshots**. Order matters — the first three
appear in search results.

## Recommended sequence (10 shots, in order)

1. **Hero / Main view** — caption: "Every subscription on Liquid Glass."
2. **Subscription detail / edit sheet** — caption: "Set due date, recurrence,
   category."
3. **Mark Paid** — caption: "One swipe to record a payment."
4. **Payment history chart** — caption: "Year → month → day drilldown."
5. **Sign in with Apple + Google** — caption: "Sign in your way."
6. **Settings** — caption: "Reminder time, currency, App Lock — all glass."
7. **Notification preview** — caption: "Quiet local reminders, never spam."
8. **Empty state** — caption: "Start fresh. Add your first subscription."
9. **Search** — caption: "Find by name, category, or status."
10. **Dark mode** — caption: "Looks the same magic in dark."

## How to capture

On the Mac:

```bash
xcrun simctl boot "iPhone 16 Pro Max"
open -a Simulator
# Drive the app to each screen, then in the simulator menu:
# Device → Trigger Screenshot (Cmd+S), or:
xcrun simctl io booted screenshot --type=png screenshots/01-hero.png
```

Drop the resulting PNGs into a `screenshots/` folder (don't commit them — App
Store Connect is the source of truth). Upload via the App Store Connect web
UI: **App Store → Version → Screenshots → 6.7" Display**.

## App Preview videos (optional)

Apple allows up to three 30-second video previews per device class. Skip for
v1 — they're a lot of work for marginal listing lift; revisit once the app is
live and you have user feedback.
