# App Store Connect Metadata

Copy these into the listing under **App Store → iOS App → Version
information**. Keep it under the listed character limits or App Store Connect
will reject the save.

## Subtitle (30 chars)

```
Subscriptions in liquid glass.
```

## Promotional text (170 chars)

```
Track every subscription, EMI, and bill on iOS 26's Liquid Glass surface. Sign in with Apple, sync via Firebase, get gentle local reminders before each due date.
```

## Description (4000 chars)

```
Varisankya keeps every recurring bill — subscriptions, EMIs, school fees,
insurance premiums — in one calm place. Built for iOS 26 and the new Liquid
Glass design language, it gives every card, pill, and button a translucent feel
that picks up your wallpaper.

WHY VARISANKYA
• Stop losing track of recurring charges that disappear into your statement.
• See "what's due this month" the moment you open the app — a single number,
  not a buried report.
• Get a quiet local notification a few days before each due date, at a time
  that fits your routine.
• Use the same data on Android (the sibling app reads the same Firestore
  documents). Sign in with Apple or Google on either device.

DESIGNED FOR iOS 26
• Liquid Glass everywhere — hero, list, sheets, status pills, tab bar.
• Native Sign in with Apple alongside Google Sign-In.
• Local notifications via UNUserNotificationCenter — no remote push, no
  marketing spam.
• Built-in Face ID / Touch ID app lock for an extra layer of privacy.

YOUR DATA STAYS YOURS
• Data lives in your own Firestore collection, scoped to your account ID.
• We do not sell or share your usage. Firebase Analytics events are
  high-level UX signals (e.g. "subscription_save") with no names or amounts
  attached.
• Account deletion is one tap in Settings.

FEATURES
• Add recurring subscriptions with custom amount, due date, recurrence
  (daily / weekly / monthly / yearly / "Every 3 Months" / custom), and
  category.
• Mark paid with a single swipe — the due date auto-advances by the
  recurrence interval.
• Record extra or past payments without disturbing the cycle.
• Bar chart of historical spend, drillable from year → month → day.
• Search and filter by category, autopay, active/paused.
• Personalised dropdown ordering — your most-used categories surface first.
• Smooth haptics + zero-toast UX (every action confirms with subtle feedback,
  never a noisy alert).
• Reminder time and "days before due" both tunable in Settings.

SUPPORT
We're on GitHub — open issues, see the source, or fork it:
https://github.com/aarshps/varisankya-ios

Privacy policy:
https://github.com/aarshps/varisankya-android/blob/main/PRIVACY.md
```

## Keywords (100 chars, comma-separated, no spaces after commas)

```
subscription,bill,reminder,recurring,expense,tracker,finance,money,liquid glass,ios26
```

## What's new in this version (4000 chars)

```
Hello, iOS! Varisankya is now available on iPhone with full Liquid Glass design,
Sign in with Apple, and end-to-end parity with the Android app's data layer.
```

## Sign-in info for App Review

Provide a real, working account so the reviewer can actually use the app. Do
**not** use your personal account.

```
Apple ID: reviewer-varisankya@yourdomain.com
Password: (set in Settings → Reviewer access)
Notes: This account already has 3 sample subscriptions seeded so you can
test the "mark paid" flow without first having to add one. Tap the FAB to add a
new one; long-swipe a row to mark paid; tap the hero card to see the chart.
```

## Privacy URL

```
https://github.com/aarshps/varisankya-android/blob/main/PRIVACY.md
```

## Support URL

```
https://github.com/aarshps/varisankya-ios/issues
```
