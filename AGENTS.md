# AI Agents Context

This is the iOS sibling of [varisankya-android](https://github.com/aarshps/varisankya-android).
Same data layer (Firestore documents are interchangeable across the two apps),
different UI runtime.

## Branch strategy

- `main` is the only canonical branch. All work lands here.
- CI runs on every push to `main` and on every pull request.

## Stack

- **Language:** Swift 6, Swift Concurrency for async work.
- **UI:** SwiftUI on iOS 26+ with the Liquid Glass APIs (`.glassEffect()`,
  `GlassEffectContainer`, `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`,
  automatic glass toolbars).
- **Backend:** Firebase iOS SDK via Swift Package Manager — Auth, Firestore,
  Analytics.
- **Auth:** Sign in with Apple (AuthenticationServices framework) + Google
  Sign-In (`google/GoogleSignIn-iOS`). Both are required for App Store
  approval, per Guideline 4.8.
- **Project files:** Xcode project is **generated** from `project.yml` by
  XcodeGen. Don't hand-edit `Varisankya.xcodeproj` (it's gitignored anyway).
- **Build environment:** macOS runner on GitHub Actions. Local builds need
  macOS + Xcode 16.

## Core agent mandates

1. **Don't commit secrets** — `GoogleService-Info.plist`, `*.p12`,
   `*.mobileprovision`, App Store Connect API `.p8` keys. The `.gitignore`
   already blocks them; if you find yourself trying to bypass it, ask the user
   first.
2. **Don't hand-edit `Varisankya.xcodeproj`.** Edit `project.yml` and let
   XcodeGen regenerate. The generated `.xcodeproj` is gitignored on purpose.
3. **Validate via CI.** When changing Swift code, push and watch the
   `iOS Build (unsigned)` workflow. There is no local "android-studio" smoke
   test we can run on Windows.
4. **Keep Firestore-document shapes identical to Android.** Field names, types,
   and the dual-write payment layout (`subscriptions/{sid}/payments/{pid}` +
   `payments/{pid}`) must match `varisankya-android` exactly. Both apps read
   the same documents.
5. **Glass invariants** — see "Design invariants" below; do not "modernise"
   away from Liquid Glass surfaces.

## Operational workflows

- **Execution:** Plan → Act → Validate cycle. Validation = "the CI build is
  green" since we can't run Xcode on Windows.
- **Sessions:** Update this file when conventions change, but don't add
  per-session activity logs — git history is authoritative.
- **App Store releases:** see `APPLE_RUNBOOK.md`.

## Design invariants — do NOT "clean up" these

1. **iOS 26 minimum.** Don't lower the deployment target. The Liquid Glass
   APIs (`.glassEffect()`, `GlassEffectContainer`, `.buttonStyle(.glass)` /
   `.buttonStyle(.glassProminent)`) are iOS-26-only. The whole visual language
   collapses if we backport.

2. **Both Sign in with Apple AND Google Sign-In are required.** Apple
   Guideline 4.8: if Google is offered, Apple must be too. Removing either
   button is an App Store rejection.

3. **Payments are dual-written.** Every payment goes to the legacy nested
   path (`users/{uid}/subscriptions/{sid}/payments/{pid}`, atomic with the
   subscription's `dueDate` advance via a batch) AND to a flat per-user
   collection (`users/{uid}/payments/{pid}`) for fast All-Payments reads. The
   flat write is best-effort; the nested write is authoritative. See
   `Services/FirestoreService.swift` and `Services/PaymentRepository.swift`.
   This invariant exists because the Android app also uses it and the two
   apps share data.

4. **Notification scheduling is local, not push.** We use
   `UNUserNotificationCenter` calendar triggers, rescheduled every time the
   app foregrounds or a subscription changes. We deliberately do *not* use
   silent pushes — iOS background processing is too restricted to do the
   network round-trip on a schedule. See the docstring on
   `NotificationScheduler` for the full rationale.

5. **Analytics params are scalars only.** `Services/Analytics.swift` is the
   single source of event names; never log subscription names, amounts, or
   document IDs — Firebase Analytics caps distinct text values at 40 per
   parameter and our event taxonomy must stay readable.

6. **No `print` for user-facing errors.** Surface via SwiftUI `alert(...)`
   or inline error text. Background-only `print` is fine for `#if DEBUG`.

7. **All transient feedback uses haptics + brief inline UI changes, never
   `UIAlertController` toasts.** Matches the Android "no-Toast" rule.

8. **Account deletion is mandatory.** Guideline 5.1.1(v) requires in-app
   account deletion. Wired through `SettingsView` → "Delete account" →
   `AuthService.deleteAccount()` → `FirestoreService.deleteAllUserData(uid:)`
   then `Auth.user.delete()`. Don't remove this button — the App Store
   pre-screen will reject the build.

## Bundle ID

`com.hora.varisankya` — registered in both Firebase (iOS app) and the Apple
Developer portal under the same Apple Developer Team.
