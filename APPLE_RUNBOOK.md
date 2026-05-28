# Apple Developer + App Store Connect Runbook

> **Note (2026-05-28):** This document was written at project start and contains
> some outdated assumptions:
> - **Enrollment** is now via the **Apple Developer iOS app only** (web enrollment
>   for individuals was deprecated in late 2024). Safari on Mac is not required.
> - **CSR / .p12 generation** does NOT require a Mac — use `scripts/generate_csr.sh`
>   + `scripts/pack_p12.sh` which use OpenSSL and work on any OS.
> - **Xcode version** is now 26.3, not 16.
>
> For the current step-by-step post-enrollment checklist, see **[POST_ENROLLMENT.md](POST_ENROLLMENT.md)**.
> This file is retained for background context and the App Store Connect / TestFlight
> sections which remain accurate.

Step-by-step path from zero (no Mac, no Apple account) to **Varisankya** live on
the App Store. Every step is something **you** physically have to do — Apple
won't let an automation or a third party act on your behalf for the enrollment,
two-factor approval, or the "Submit for Review" button.

Estimated calendar time: **5–10 days** total, almost all of it Apple-side
waiting (enrollment review, App Review). Active hands-on time is ~3-4 hours
spread across that window.

Cost: **$99 USD / year** for the Apple Developer Program.

---

## Stage 0 — Prerequisites

You need:

1. **A Mac running macOS 14.6 or newer.** Xcode 16 (which builds iOS 26 apps)
   requires it. Options if you don't own one:
   - Borrow a friend's Mac for an afternoon (you need it once to enrol your
     Apple ID into the Developer Program). After that, the CI runner builds for
     you so you don't need ongoing Mac access.
   - Rent a cloud Mac: [MacStadium](https://www.macstadium.com/) (~$60/month
     mini), [MacinCloud](https://www.macincloud.com/) (~$30/month pay-as-you-go).
     Cheaper if you only need a week.
   - Your CI runner *can* archive, export and upload — but enrollment requires
     a Safari session on a Mac, so you can't fully avoid this step.
2. **An Apple ID with two-factor authentication enabled.** Required for
   enrollment, App Store Connect access, and signing certificates. Create one
   at <https://appleid.apple.com> if you don't have one.
3. **A credit/debit card.** Apple charges the $99 enrollment fee immediately.
4. **Government photo ID nearby.** Apple sometimes asks for it during identity
   verification (rare for Individual accounts, common for Organization).
5. **A phone you control.** 2FA codes land here.

---

## Stage 1 — Enroll in the Apple Developer Program

1. On any device, visit <https://developer.apple.com/programs/enroll/>.
2. Click **Start Your Enrollment** → sign in with the Apple ID from Stage 0.
3. Pick an entity type:
   - **Individual / Sole Proprietor** — fastest, no D-U-N-S number required, app
     listings show your personal name. Pick this unless you have a registered
     company.
   - **Organization** — requires a D-U-N-S number (free to look up but takes
     1–5 business days to issue). App listings show the company name. Required
     if you ever want multiple team members or to publish under a brand.
4. Enter your legal name and address. Submit.
5. Pay the $99 with the card. Apple emails you when the account is approved —
   normally **within 24–48 hours**, occasionally up to a week if they request
   ID verification.
6. Once you receive the **Welcome to the Apple Developer Program** email,
   confirm you can sign in at <https://developer.apple.com/account/>.

> **Need to do this in your Edge browser?** Yes — Apple's enrollment flow runs
> fine in Edge/Chrome. The only step that truly requires a Mac is creating the
> distribution certificate (Stage 3); enrollment itself is browser-only.

---

## Stage 2 — Provision the Firebase iOS App

The Android app already has a Firebase project. You'll add an iOS app inside
the **same** project so a single user account sees their data on both
platforms.

1. Go to <https://console.firebase.google.com>, open the existing
   `varisankya` project.
2. **Project settings → Your apps → Add app → iOS+ icon**.
3. Bundle ID: `com.hora.varisankya` (exactly — must match `project.yml`).
4. App nickname: `Varisankya iOS`.
5. Download the generated `GoogleService-Info.plist`. **Keep this file safe —
   it contains your API keys (read-only by design, but still confidential).**
6. Drop the file into `Varisankya/Resources/GoogleService-Info.plist` locally.
   Don't commit it (the `.gitignore` blocks it). For CI you'll add a base64
   version as a GitHub Secret in Stage 5.
7. In the Firebase console, **enable Apple as a sign-in provider** under
   **Authentication → Sign-in method → Apple**. The configuration is empty by
   default; just toggle it on. Firebase handles Apple's OIDC handshake without
   any extra IDs.
8. Confirm **Google** is enabled as a sign-in provider too (Android already
   uses it). The web client ID from Android's `WEB_CLIENT_ID` constant is
   shared.

---

## Stage 3 — Create signing assets on the Mac

These exist only on macOS. Do this once; the certificate is valid for one year.

1. On the Mac, open the Keychain Access app.
2. **Keychain Access → Certificate Assistant → Request a Certificate From a
   Certificate Authority…**
   - Email: the Apple ID email.
   - Common name: `Varisankya Distribution`.
   - Choose **Saved to disk** + **Let me specify key pair information** →
     2048 bits, RSA. Save the `.certSigningRequest` file.
3. Visit <https://developer.apple.com/account/resources/certificates/list>:
   - **+ Add → Apple Distribution**.
   - Upload the `.certSigningRequest`.
   - Download the resulting `.cer` file.
4. Double-click the `.cer` to install it into the Keychain.
5. In Keychain Access, find the cert under **login → My Certificates**, expand
   it (private key should appear beneath), right-click → **Export…**, save as
   `Varisankya-Distribution.p12` with a strong password — **remember this
   password**, you'll need it as `P12_PASSWORD` in Stage 5.

---

## Stage 4 — Register the App and create the Provisioning Profile

1. <https://developer.apple.com/account/resources/identifiers/list> →
   **+ → App IDs → App → Continue**.
   - Description: `Varisankya`.
   - Bundle ID: **Explicit** → `com.hora.varisankya`.
   - Capabilities (tick): **Push Notifications**, **Sign In with Apple**.
   - Register.
2. <https://developer.apple.com/account/resources/profiles/list> →
   **+ → App Store → Continue**.
   - App ID: `com.hora.varisankya`.
   - Certificate: the Distribution certificate from Stage 3.
   - Profile name: `Varisankya AppStore` (must match the `EXPORT_OPTIONS`
     plist in `.github/workflows/ios-release.yml`).
   - Generate, then **Download** the `.mobileprovision` file.

---

## Stage 5 — Create the App Store Connect listing

1. Visit <https://appstoreconnect.apple.com> with the same Apple ID.
2. **Apps → + → New App**.
   - Platform: iOS.
   - Name: `Varisankya`.
   - Primary language: English (U.S.).
   - Bundle ID: pick `com.hora.varisankya - Varisankya`.
   - SKU: `varisankya-ios` (internal, doesn't show anywhere).
   - User Access: Full Access.
3. Once created, fill out **App Information**:
   - Privacy Policy URL: <https://github.com/aarshps/varisankya-android/blob/main/PRIVACY.md>
   - Category Primary: **Finance**; Secondary: **Productivity**.
   - Content Rights: confirm you own all content.
   - Age Rating: complete the questionnaire (likely 4+).
4. **Pricing and Availability** → Free, available in all territories.
5. **App Privacy** → use the table from
   [PRIVACY_LABELS.md](PRIVACY_LABELS.md) in this repo.
6. **Prepare for Submission** (for the first version):
   - Screenshots: see [SCREENSHOTS.md](SCREENSHOTS.md). You can take these on
     the iOS Simulator on the Mac.
   - Promotional text (170 chars): see [METADATA.md](METADATA.md).
   - Description (4,000 chars): see [METADATA.md](METADATA.md).
   - Keywords (100 chars): `subscription,bill,reminder,expense,tracker,recurring,finance,money,liquid glass`
   - Support URL: <https://github.com/aarshps/varisankya-ios/issues>
   - Marketing URL: optional, leave blank.
   - Sign-in info for Apple reviewers: create a *test* Google account or a
     dedicated Apple ID. Fill the **Sign-in required** section with credentials
     so the reviewer can actually exercise the app. **Don't use your personal
     account.**

---

## Stage 6 — Generate App Store Connect API key (for CI uploads)

The CI uploads via `xcrun altool` using an API key (not your password).

1. <https://appstoreconnect.apple.com/access/integrations/api/users> →
   **Users and Access → Integrations → App Store Connect API**.
2. **Generate API Key**: give it a name (e.g. `Varisankya CI`), pick role
   **Developer** (enough for uploads). Click Generate.
3. Note the **Issuer ID** at the top of the page → that becomes
   `APPLE_API_ISSUER_ID`.
4. Each key has a **Key ID** → that becomes `APPLE_API_KEY_ID`.
5. **Download** the `.p8` private key — Apple lets you download it once.

---

## Stage 7 — Add GitHub Secrets

Repository → **Settings → Secrets and variables → Actions → New repository
secret**. Add all of these:

| Secret | What it is | How to fill it |
| --- | --- | --- |
| `APPLE_TEAM_ID` | 10-character team ID | <https://developer.apple.com/account#MembershipDetailsCard> → "Team ID" |
| `APPLE_API_ISSUER_ID` | UUID | Stage 6 step 3 |
| `APPLE_API_KEY_ID` | 10 characters | Stage 6 step 4 |
| `APPLE_API_KEY_BASE64` | base64 of the `.p8` | `base64 -i AuthKey_XXXX.p8 \| pbcopy` |
| `BUILD_CERTIFICATE_BASE64` | base64 of the `.p12` | `base64 -i Varisankya-Distribution.p12 \| pbcopy` |
| `P12_PASSWORD` | password chosen in Stage 3 step 5 | the literal password |
| `PROVISIONING_PROFILE_BASE64` | base64 of the `.mobileprovision` | `base64 -i Varisankya_AppStore.mobileprovision \| pbcopy` |
| `KEYCHAIN_PASSWORD` | any strong random string | the CI uses this only inside the temporary keychain it creates and destroys; pick anything |
| `GOOGLE_SERVICE_INFO_BASE64` | base64 of `GoogleService-Info.plist` | `base64 -i GoogleService-Info.plist \| pbcopy` |

After saving them, also create an **Environment** named `appstore`:
**Settings → Environments → New environment**. Add the same secrets under
this environment. (The release workflow runs `environment: appstore`, which
adds an extra "review required" gate before any signed build happens.)

---

## Stage 8 — First upload to TestFlight

1. On GitHub: **Actions → iOS Release (TestFlight) → Run workflow**, pick
   `track: testflight`, `bump_build: true`. Run.
2. ~12–18 minutes later the IPA appears in App Store Connect under
   **TestFlight → Builds**. State: "Processing" (~5–10 min).
3. Once it shows "Ready to Submit":
   - Add **Test Information** (what to test, the same sign-in credentials).
   - Add an **internal test group** (you yourself counts) → Apple emails you a
     download link via the TestFlight app on your iPhone.
   - Optional: add **external testers** → 24-hour Apple review of the build
     before they can install.
4. Install via TestFlight on your iPhone. Verify sign-in (both Apple and
   Google), add a subscription, mark paid, see the notification fire.

---

## Stage 9 — Submit for App Store review

1. In App Store Connect, the new version (`3.8` or whatever you set
   `MARKETING_VERSION` to) appears under your app's **App Store** tab.
2. Under **Build**, pick the TestFlight build you just verified.
3. Confirm screenshots, description, keywords, sign-in info are populated.
4. **Save → Add for Review → Submit for Review**.
5. Apple's review: typically **24–48 hours**, occasionally up to 7 days. You
   may get questions via App Store Connect Resolution Center; respond promptly.
6. On approval, the app goes live within a few hours (or at the date you
   scheduled).

---

## Things that commonly trip people up (preempt them)

- **Sign in with Apple is mandatory.** Guideline 4.8: if you offer Google
  Sign-In, you *must* also offer Sign in with Apple. The code in this repo
  already does both — don't remove the Apple button.
- **Privacy labels must be exhaustive.** Even though you don't use third-party
  analytics SDKs, Firebase Analytics counts. Mirror [PRIVACY_LABELS.md](PRIVACY_LABELS.md)
  exactly.
- **Encryption export compliance.** The Info.plist already declares
  `ITSAppUsesNonExemptEncryption = false` (Firebase uses TLS which is exempt).
  If you ever add a custom cipher you'll need to amend this.
- **Account deletion.** Guideline 5.1.1(v) requires in-app account deletion.
  Wired in `SettingsView.swift` → "Delete account" → confirms, then calls
  `AuthService.deleteAccount()` which best-effort wipes the user's Firestore
  data then `Auth.user.delete()`. If Firebase returns
  `requiresRecentLogin`, the UI prompts the user to sign out, sign back in,
  and retry within the same session — this is the documented Firebase
  behaviour for accounts that haven't authenticated recently.
- **Test sign-in credentials in the review notes are not optional.** If you
  leave them blank, Apple rejects the build because they can't get past the
  sign-in screen.

---

## What I (the assistant) can drive via your Edge browser later

Once you say go, I can use Playwright to:

- Open the Firebase Console "Add iOS app" flow and pre-fill the bundle ID +
  nickname; you click through 2FA / OAuth screens.
- Open <https://developer.apple.com/account/resources/identifiers/list> and
  fill the App ID form; you handle the 2FA prompt.
- Open the App Store Connect "New App" form; you confirm the metadata.
- Open the GitHub Secrets settings page and pre-paste each value once you've
  generated them on the Mac.

What I cannot drive: the *creation of the .p12 / .mobileprovision on the Mac*
(Keychain Access is a macOS app, not a website). For everything browser-based,
say **"drive the apple steps"** when you're ready.
