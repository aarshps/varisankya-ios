# AI Agents Context

Authoritative context file for AI agents working on this project. Keep this
file up to date when conventions change. Do **not** add per-session activity
logs here — git history and commit messages are the authoritative record.

This is the iOS sibling of [varisankya-android](https://github.com/aarshps/varisankya-android).
Same Firestore data layer (documents are interchangeable), different UI runtime.

---

## Branch strategy

- `main` is the only canonical branch. All work lands here.
- CI runs on every push to `main` and on every pull request.
- Tag `v*` triggers the signed TestFlight release workflow.

---

## Stack

| Layer | Technology | Notes |
| --- | --- | --- |
| Language | **Swift 5.0 language mode** | NOT Swift 6. `SWIFT_VERSION: "5.0"` + `SWIFT_STRICT_CONCURRENCY: minimal`. Firebase iOS SDK 11.x hasn't completed Sendable migration; revisit when firebase-ios-sdk v12+ ships full Sendable conformance. |
| UI | SwiftUI, iOS 26+ | Liquid Glass APIs: `.glassEffect(in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`, automatic glass toolbars. Deployment target: iOS 26.0. |
| Backend | Firebase iOS SDK v11.15.0 | Via Swift Package Manager. Products used: FirebaseAuth, FirebaseFirestore, FirebaseAnalytics, FirebaseMessaging. |
| Auth | Sign in with Apple + Google Sign-In | **Both are mandatory** per App Store Guideline 4.8. Removing either = instant rejection. Framework: AuthenticationServices (Apple), GoogleSignIn-iOS v8.0.0 (Google). |
| State management | `@Observable` (Observation framework) | ViewModels injected via `@Environment(Type.self)`. Not `@ObservableObject` / `@StateObject`. |
| Project generation | XcodeGen | `project.yml` → `Varisankya.xcodeproj`. The generated `.xcodeproj` is gitignored. Never hand-edit it. |
| Build environment | GitHub Actions `macos-latest` + Xcode 26.3 | Via `maxim-lobanov/setup-xcode@v1 latest-stable`. No local Mac required for CI. Local builds need macOS + Xcode 26+. |

---

## Firebase configuration

| Item | Value |
| --- | --- |
| Firebase project | `helloworld-92567418` |
| iOS bundle ID | `com.hora.varisankya` |
| Android project | shares the same Firebase project |
| Auth providers enabled | Google, Apple (both in Firebase Console → Authentication → Sign-in method) |
| GoogleService-Info.plist | gitignored; download from Firebase Console → Project settings → Your apps → Varisankya iOS; in CI it is base64-decoded from `GOOGLE_SERVICE_INFO_BASE64` secret |
| Google Sign-In URL scheme | `REVERSED_CLIENT_ID` from the plist: `com.googleusercontent.apps.663138385072-03ftaplr577nmc0bl88gj59spqis58ql` |
| Firestore | same rules/layout shared with Android; see "Firestore data model" below |

---

## Core agent mandates

1. **Never commit secrets.** `GoogleService-Info.plist`, `*.p12`, `*.cer`,
   `*.mobileprovision`, App Store Connect API `.p8` keys are all in `.gitignore`.
   If you find yourself trying to bypass that, ask the user first.

2. **Never hand-edit `Varisankya.xcodeproj`.** Edit `project.yml` and let
   XcodeGen regenerate. The `.xcodeproj` is gitignored.

3. **Validate via CI.** When changing Swift code, push and watch the
   `iOS Build (unsigned)` workflow. There is no local Xcode/Simulator on
   Windows.

4. **Keep Firestore document shapes identical to Android.** Field names, types,
   and the dual-write payment layout must match `varisankya-android` exactly.
   Both apps read the same Firestore collections.

5. **Glass invariants** — see "Design invariants" below.

6. **Do not lower the iOS deployment target.** Liquid Glass is iOS 26-only.

---

## Design invariants — do NOT "clean up" these

1. **iOS 26 minimum.** Deployment target is `26.0`. The `.glassEffect()`,
   `GlassEffectContainer`, and `.buttonStyle(.glass)` APIs are iOS-26-only.

2. **Both Sign in with Apple AND Google Sign-In are required.** App Store
   Guideline 4.8: if Google is offered, Apple must be too. Code is in
   `SignInView.swift`.

3. **Payments are dual-written.** Every payment is written to:
   - `users/{uid}/subscriptions/{sid}/payments/{pid}` (authoritative, atomic with `dueDate` advance via Firestore batch)
   - `users/{uid}/payments/{pid}` (flat mirror for fast All-Payments reads, best-effort)
   
   The flat write must never replace the nested write as the source of truth.
   This matches Android's layout exactly. See `FirestoreService.swift` and
   `PaymentRepository.swift`.

4. **Notification scheduling is local, not push.** Uses
   `UNUserNotificationCenter` calendar triggers, rescheduled every time the
   app foregrounds or a subscription changes. No silent pushes — iOS background
   processing is too restricted for the network round-trip on a schedule.
   Rationale in `NotificationScheduler.swift`.

5. **Analytics params are scalars only.** `Analytics.swift` is the single
   source of event names. Never log subscription names, amounts, or document
   IDs — Firebase Analytics caps distinct text values per parameter at 40.

6. **No `print` for user-facing errors.** Surface via SwiftUI `alert(...)` or
   inline error text. `print` is fine in `#if DEBUG`.

7. **All transient feedback uses haptics + brief inline UI changes, never
   `UIAlertController` toasts.** Mirrors the Android "no-Toast" rule.

8. **Account deletion is mandatory.** Guideline 5.1.1(v). Wired through
   `SettingsView` → "Delete account" → `AuthService.deleteAccount()` →
   `FirestoreService.deleteAllUserData(uid:)` then `Auth.user.delete()`.
   Do not remove this button.

---

## XcodeGen — project.yml specifics

Key settings that deviate from XcodeGen defaults or have caused past failures:

```yaml
options:
  deploymentTarget:
    iOS: "26.0"          # Must match IPHONEOS_DEPLOYMENT_TARGET

settings:
  base:
    SWIFT_VERSION: "5.0"              # NOT "6.0" — Firebase Sendable migration incomplete
    SWIFT_STRICT_CONCURRENCY: minimal # NOT complete — same reason
    IPHONEOS_DEPLOYMENT_TARGET: "26.0"
    TARGETED_DEVICE_FAMILY: "1"       # iPhone only (not iPad/Mac)
    SUPPORTS_MACCATALYST: "NO"

packages:
  Firebase:
    url: https://github.com/firebase/firebase-ios-sdk
    from: "11.0.0"        # Use `from:` NOT `minVersion:` — XcodeGen rejects minVersion alone
  GoogleSignIn:
    url: https://github.com/google/GoogleSignIn-iOS
    from: "8.0.0"
```

Known XcodeGen pitfalls:
- **`minVersion:` without `maxVersion:` is invalid** → use `from:` (up-to-next-major)
- **`scheme.configVariants` lists default configs** → XcodeGen creates Debug/Release by default; listing them as configVariants causes a validation error. Remove the block entirely.
- **Google Sign-In URL scheme** must be set via env var `GOOGLE_SIGN_IN_URL_SCHEME` in the workflow; XcodeGen reads it from `$(GOOGLE_SIGN_IN_URL_SCHEME)` in project.yml. The CI workflow extracts `REVERSED_CLIENT_ID` from the decoded `GoogleService-Info.plist` and exports it before calling `xcodegen generate`.

---

## CI workflows

### `ios-build.yml` — unsigned build (runs on every push)

Purpose: prove the code compiles cleanly against iOS 26 SDK.

```yaml
runs-on: macos-latest
steps:
  - uses: maxim-lobanov/setup-xcode@v1
    with:
      xcode-version: latest-stable    # resolves to Xcode 26.3 today
  - brew install xcodegen
  - # Generate placeholder GoogleService-Info.plist if real secret missing
  - # Generate placeholder AppIcon-1024.png via scripts/generate_icon.swift
  - xcodegen generate
  - xcodebuild -resolvePackageDependencies
  - xcodebuild \
      -sdk iphoneos \
      -destination 'generic/platform=iOS' \   # device, not Simulator
      CODE_SIGN_IDENTITY="" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO \
      build
```

**Why device build, not Simulator?** `macos-latest` runners don't always have
iOS Simulator runtimes installed, even for "current" iOS. Building for
`iphoneos` (real-device SDK, unsigned) sidesteps the runtime dependency with
zero tradeoffs — same compiler, same SDK.

### `ios-release.yml` — signed archive → TestFlight (manual / tag-triggered)

Requires 9 GitHub Secrets (see below). Steps: checkout → setup-xcode →
decode signing assets into temp keychain → decode GoogleService-Info.plist
→ bump build number to `YYYYMMDDHHMM` → xcodegen generate → resolve packages
→ archive → export IPA → upload via `xcrun altool` → clean up keychain.

Trigger:
```bash
gh workflow run ios-release.yml -f track=testflight -f bump_build=true
```

---

## GitHub Secrets required (9 total)

| Secret | Status | Description |
| --- | --- | --- |
| `GOOGLE_SERVICE_INFO_BASE64` | ✅ **SET** | base64 of `GoogleService-Info.plist` |
| `APPLE_TEAM_ID` | ❌ pending enrollment | 10-char team ID from developer.apple.com/account |
| `APPLE_API_ISSUER_ID` | ❌ pending enrollment | UUID from App Store Connect → Integrations → API |
| `APPLE_API_KEY_ID` | ❌ pending enrollment | 10-char key ID |
| `APPLE_API_KEY_BASE64` | ❌ pending enrollment | base64 of the `.p8` private key |
| `BUILD_CERTIFICATE_BASE64` | ❌ pending enrollment | base64 of Distribution `.p12` |
| `P12_PASSWORD` | ❌ pending enrollment | passphrase chosen during `scripts/pack_p12.sh` |
| `PROVISIONING_PROFILE_BASE64` | ❌ pending enrollment | base64 of `Varisankya_AppStore.mobileprovision` |
| `KEYCHAIN_PASSWORD` | ❌ pending enrollment | any strong random string; CI uses only internally |

Run `./scripts/check_apple_secrets.sh` to audit which are set.

---

## Apple Developer enrollment — current state (as of 2026-05-28)

| Item | Detail |
| --- | --- |
| Apple ID | `aarshps@gmail.com` |
| Legal name on Apple ID | `Adarsh P S` (corrected 2026-05-28 to match Aadhaar) |
| Enrollment status | **REJECTED** — automated identity check (Gate 1) |
| Root cause | Last name was "Ps" (two lowercase letters, no vowel): heuristic rejected it as non-real. Fixed to "P S" (space-separated initials matching Aadhaar). |
| Support case | **#102900128848**, agent: Yana (asia.dev@apple.com) |
| Support case status | We replied 2026-05-28 ~10:21 IST with a screenshot of "ID Verification Rejected" status + requested specific rejection reason and a verification state reset. **Awaiting Yana's next reply.** |
| Re-enrollment path | Apple Developer **iOS app** only (web enrollment deprecated for individuals in late 2024). No browser path available. |
| Re-enrollment blocker | Must also have: billing address + payment method on the Apple Account (apple.com/account/manage) before re-attempting; these were missing on first attempt. |
| ID for re-enrollment | **Passport or PAN card** — NOT Aadhaar (Apple rejects Aadhaar per UIDAI commercial-use restriction). |

### When Yana replies, expect one of:

| Yana says | My action |
| --- | --- |
| Specific rejection reason (e.g. "address mismatch") | Fix exactly that field; guide re-enrollment |
| "I've reset your verification, please re-enroll" | Walk through iOS app re-enrollment: Account tab → Enroll → Individual → proceed to doc upload |
| Asks for a verification call or more documents | Prep: schedule call or identify correct document |

### Re-enrollment steps once unblocked:

1. Verify billing address is set on account.apple.com (billing addresses, not just shipping)
2. Verify payment method (credit card) is on the account
3. In Apple Developer iOS app: Account → Enroll → Individual
4. Upload Passport or PAN card when prompted (NOT Aadhaar)
5. Pay $99

---

## Post-enrollment next steps (summary)

Full detail in `POST_ENROLLMENT.md`. Quick reference:

| Stage | Action | Time |
| --- | --- | --- |
| A | `./scripts/generate_csr.sh aarshps@gmail.com "Varisankya Distribution" IN "Adarsh P S"` → upload `Varisankya.csr` at developer.apple.com/account/resources/certificates/add → download `distribution.cer` → `./scripts/pack_p12.sh distribution.cer` → set `BUILD_CERTIFICATE_BASE64` + `P12_PASSWORD` secrets | 10 min |
| B | Register App ID `com.hora.varisankya` with Push Notifications + Sign In with Apple at developer.apple.com/account/resources/identifiers | 3 min |
| C | Create provisioning profile named **exactly** `Varisankya AppStore` at developer.apple.com/account/resources/profiles → set `PROVISIONING_PROFILE_BASE64` secret | 2 min |
| D | Create App Store Connect API key (Developer role) at appstoreconnect.apple.com/access/integrations/api → set `APPLE_TEAM_ID` + `APPLE_API_ISSUER_ID` + `APPLE_API_KEY_ID` + `APPLE_API_KEY_BASE64` + `KEYCHAIN_PASSWORD` secrets | 5 min |
| E | `./scripts/check_apple_secrets.sh` — confirm all 9 green | 1 min |
| F | Create App Store Connect listing (name: `Varisankya`, bundle ID: `com.hora.varisankya`, free, all territories) using metadata from `METADATA.md` + `PRIVACY_LABELS.md` | 10 min |
| G | `gh workflow run ios-release.yml -f track=testflight -f bump_build=true` → install via TestFlight on iPhone | 20 min |
| H | App Store Connect → Select build → Add for Review → Submit | 15 min |

I can drive stages A–F via Playwright in Edge once enrollment clears.

---

## Known compiler pitfalls (and their fixes)

| Symptom | Cause | Fix |
| --- | --- | --- |
| "stored property '_id' of 'Sendable'-conforming struct has non-Sendable type" | Firebase `@DocumentID` is not Sendable in SDK 11.x | Drop `Sendable` conformance from model structs; keep `SWIFT_STRICT_CONCURRENCY: minimal` |
| "main actor-isolated property can not be referenced from a nonisolated context" (in deinit) | `deinit` is nonisolated but class is `@MainActor` | If singleton: remove deinit. If non-singleton: use `isolated deinit` (Swift 5.10+) or a Task |
| "'init()' was deprecated in iOS 26.0: Use init(windowScene:) instead" | Bare `UIWindow()` call | Replace with scene-based init; see `AuthService.swift` `presentationAnchor` for the pattern |
| "no 'async' operations occur within 'await' expression" | `await` on non-isolated non-async property | Remove the `await` |
| "OpenURLOptionsKey deprecated" | `UIApplicationDelegate application(_:open:options:)` uses deprecated key | Delete the delegate method; SwiftUI `.onOpenURL` handles URL callbacks via UIScene pipeline |

---

## Firestore data model

Field names and types must match Android exactly (shared project, same documents):

```
users/{uid}/
  subscriptions/{subId}           Subscription document
    .name: String
    .amount: Double
    .currencyCode: String         ISO-4217, e.g. "INR"
    .recurrence: String           "Monthly" | "Yearly" | "Weekly" | "Every 3 Months" | "Custom"
    .dueDate: Timestamp
    .category: String?
    .notes: String?

  subscriptions/{subId}/payments/{paymentId}    (authoritative payment record)
    .amount: Double
    .date: Timestamp
    .note: String?

  payments/{paymentId}            (flat mirror — same data, for fast All-Payments reads)
    .amount: Double
    .date: Timestamp
    .subscriptionId: String
    .subscriptionName: String
    .note: String?
```

Recurrence encoding: stored as human-readable string. `Recurrence.swift` handles
encode/decode and `nextDueDate(from:)` UTC math. Same strings used by Android.

---

## Key files reference

| Path | Purpose |
| --- | --- |
| `project.yml` | XcodeGen spec; single source of truth for build settings and dependencies |
| `Varisankya/App/VarisankyaApp.swift` | App entry point; Firebase init; `.onOpenURL` for Google Sign-In |
| `Varisankya/App/RootView.swift` | Root switcher: shows SignInView or MainView based on auth state |
| `Varisankya/Services/AuthService.swift` | `@MainActor` singleton; Sign in with Apple + Google; `presentationAnchor` pattern for iOS 26 |
| `Varisankya/Services/FirestoreService.swift` | Observe subscriptions; upsert; dual-write payments; `deleteAllUserData` |
| `Varisankya/Services/PaymentRepository.swift` | Flat payments collection read + dual-write mirror |
| `Varisankya/Services/NotificationScheduler.swift` | `UNUserNotificationCenter` calendar triggers; reschedule on foreground |
| `Varisankya/Services/Preferences.swift` | `@Observable` plain class; persists user settings via `UserDefaults` |
| `Varisankya/Models/Subscription.swift` | Codable + `@DocumentID`; no explicit CodingKeys |
| `Varisankya/Models/PaymentRecord.swift` | Codable + `@DocumentID`; no explicit CodingKeys |
| `Varisankya/Models/Recurrence.swift` | Enum with string encoding + `nextDueDate(from:)` |
| `Varisankya/Resources/Info.plist` | `NSFaceIDUsageDescription`, `NSUserTrackingUsageDescription`, `ITSAppUsesNonExemptEncryption=false` |
| `Varisankya/Resources/Varisankya.entitlements` | `com.apple.developer.applesignin Default`, `aps-environment development` |
| `scripts/generate_csr.sh` | OpenSSL CSR for Apple Distribution cert; no Mac required |
| `scripts/pack_p12.sh` | Combines key + signed cert into `.p12`; outputs base64 for GitHub Secret |
| `scripts/check_apple_secrets.sh` | Audits all 9 required GitHub Secrets |
| `scripts/generate_icon.swift` | Renders placeholder app icon PNG for CI (replace before App Store submission) |
| `.github/workflows/ios-build.yml` | Unsigned device build; runs on every push |
| `.github/workflows/ios-release.yml` | Signed archive + TestFlight upload; manual / `v*` tag |
| `POST_ENROLLMENT.md` | 8-stage checklist: from Apple welcome email to TestFlight (~45 min) |
| `APPLE_RUNBOOK.md` | Background reading on Apple enrollment; some sections predate current scripts — treat as supplementary |
| `METADATA.md` | App Store listing copy (name, subtitle, description, keywords) |
| `PRIVACY_LABELS.md` | App Privacy nutrition label answers for App Store Connect |
| `SCREENSHOTS.md` | Screenshot device sizes and capture instructions |

---

## Bundle ID

`com.hora.varisankya` — registered in Firebase (iOS app `helloworld-92567418`)
and will be registered in the Apple Developer portal once enrollment clears.

---

## Operational workflows

- **Plan → Act → Validate.** Validation = "CI is green" since Xcode doesn't
  run on Windows.
- **I can drive browser steps via Playwright in Edge.** Say "drive [step]" for
  any Apple/Firebase/GitHub web action. I'll stop before entering card details
  and call for human input.
- **Enrollment re-attempt is iOS-only.** Open the Apple Developer app on the
  user's iPhone (not a browser). There is no web enrollment path for
  individuals since late 2024.
- **Card details must not go through Playwright.** The screenshot/snapshot log
  would expose them. I stop at the card-entry screen and hand off to the user.
