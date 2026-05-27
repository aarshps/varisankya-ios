# Varisankya for iOS

iOS sibling of the [Varisankya Android](https://github.com/aarshps/varisankya-android) subscription
manager. SwiftUI, iOS 26+ Liquid Glass, Firebase Auth + Firestore, Sign in with Apple +
Google Sign-In. Same Firebase project, same Firestore documents — sign in on either platform and
see the same subscriptions.

Wiki: <https://github.com/aarshps/varisankya-ios/wiki>

## Status

| Surface | State |
| --- | --- |
| Source code | All screens ported, 0 warnings, 0 errors on iOS 26 SDK |
| CI | Green at every push — [latest run](https://github.com/aarshps/varisankya-ios/actions) |
| Firebase | iOS app registered in `helloworld-92567418`, Auth providers Google + Apple enabled, Firestore rules already permit iOS layout |
| App Store | Pending Apple Developer Program enrollment (see [POST_ENROLLMENT.md](POST_ENROLLMENT.md)) |

## What this repo contains

| Path | Purpose |
| --- | --- |
| `project.yml` | XcodeGen spec — `.xcodeproj` is generated on the build machine, not stored in git |
| `Varisankya/App/` | App entry point, root view, `UIApplicationDelegate` for Firebase init |
| `Varisankya/Models/` | `Subscription`, `PaymentRecord`, currency/recurrence helpers |
| `Varisankya/Services/` | `AuthService`, `FirestoreService`, `PaymentRepository`, `NotificationScheduler`, `Preferences`, `Analytics`, `BiometricAuth` |
| `Varisankya/ViewModels/` | `MainViewModel`, `SearchViewModel`, `HistoryViewModel` (all `@Observable`) |
| `Varisankya/Views/` | SwiftUI screens with Liquid Glass treatment |
| `Varisankya/Resources/` | `Info.plist`, asset catalog, entitlements |
| `scripts/generate_icon.swift` | Placeholder app-icon generator used by CI |
| `.github/workflows/` | CI: unsigned build on every push; signed TestFlight release on manual dispatch |

## Build locally (macOS only)

```bash
brew install xcodegen
xcodegen generate
open Varisankya.xcodeproj
```

Place a real `GoogleService-Info.plist` in `Varisankya/Resources/` before sign-in
and Firestore will work. See [APPLE_RUNBOOK.md](APPLE_RUNBOOK.md) for the
Firebase + Apple Developer + App Store Connect setup walkthrough.

## CI

- `ios-build.yml` runs on every push to `main` and every pull request. It uses a
  macOS 15 runner, generates the project with XcodeGen, and builds an unsigned
  Debug build to validate compilation.
- `ios-release.yml` is manually triggered (`workflow_dispatch`) or fires on `v*`
  tags. It signs with your Distribution certificate, archives, exports an IPA,
  and uploads to App Store Connect / TestFlight via `xcrun altool` with App
  Store Connect API key auth.

See [APPLE_RUNBOOK.md](APPLE_RUNBOOK.md) for the complete list of GitHub
Secrets the release workflow expects.

## Design language

- Targets iOS 26+ exclusively so the **Liquid Glass** APIs are available:
  `.glassEffect(in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)` /
  `.buttonStyle(.glassProminent)`, automatic glass toolbars.
- All persistent surfaces (cards, rows, the hero, pills, the FAB, sheets,
  status badges) sit on translucent glass against a soft accent-tinted
  background — the wallpaper visible through every layer is the visual hook.
- Haptics mirror the Android M3 expressive scheme (`tick`, `click`, `success`,
  `warning`, `error`) — see `Services/Haptics.swift`.

## Parity with Android

The Firestore document layout is **identical** so a single user can sign in on
both platforms and see the same data:

- `users/{uid}/subscriptions/{subId}`
- `users/{uid}/subscriptions/{subId}/payments/{paymentId}` *(authoritative)*
- `users/{uid}/payments/{paymentId}` *(flat mirror for fast All-Payments reads)*

Recurrence strings ("Monthly", "Every 3 Months", "Custom") encode the same way.
Notification scheduling differs by platform: Android uses a chained
`WorkManager` worker; iOS uses local
`UNUserNotificationCenter` requests rescheduled every time the app foregrounds.
See `Services/NotificationScheduler.swift` for the rationale.

## Bundle ID + Firebase

- iOS bundle ID: `com.hora.varisankya`
- Firebase iOS app: registered in the `helloworld-92567418` project (same one
  the Android app uses) — both apps therefore share Auth and Firestore. The
  `GoogleService-Info.plist` is already downloaded; place it locally at
  `Varisankya/Resources/GoogleService-Info.plist` (gitignored). CI reads it
  from the `GOOGLE_SERVICE_INFO_BASE64` GitHub Secret (already set).

## Companion docs

- [POST_ENROLLMENT.md](POST_ENROLLMENT.md) — 8-stage checklist from the
  Apple Developer welcome email to TestFlight (~45 min)
- [APPLE_RUNBOOK.md](APPLE_RUNBOOK.md) — Apple Developer enrollment +
  cert/profile/listing background
- [METADATA.md](METADATA.md) — App Store listing copy
- [PRIVACY_LABELS.md](PRIVACY_LABELS.md) — App Privacy nutrition labels
- [SCREENSHOTS.md](SCREENSHOTS.md) — Screenshot capture spec
- [AGENTS.md](AGENTS.md) — agent contract / design invariants

## Scripts (`scripts/`)

| Script | Purpose |
| --- | --- |
| `generate_icon.swift` | Renders placeholder 1024×1024 PNG app icon (used by CI) |
| `generate_csr.sh` | One-shot OpenSSL to produce the Apple Distribution CSR (no Mac required) |
| `pack_p12.sh` | Combines CSR private key + Apple's signed `.cer` into a `.p12`, base64-encodes it |
| `check_apple_secrets.sh` | Audits which of the 9 release-workflow GitHub Secrets are set |
