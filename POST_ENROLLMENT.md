# Post-Enrollment Checklist

Use this the moment Apple emails **"Welcome to the Apple Developer Program"**.
Every step has a paste-ready command or an exact URL. Total active time:
~45 minutes.

> ⚠ Tested for the **Individual** enrollment path. Organization steps differ
> slightly (App Store Connect role assignments, D-U-N-S verification).

---

## Quick orientation: what you have vs. what's missing

| Already done (today) | Pending |
| --- | --- |
| ✅ Firebase iOS app registered, `GoogleService-Info.plist` placed | Apple Developer enrollment |
| ✅ Apple ID name set to "Adarsh P S" matching Aadhaar | App ID + capabilities |
| ✅ Firebase Auth: Google + Apple providers enabled | Distribution certificate |
| ✅ Firestore rules already cover iOS layout | Provisioning profile |
| ✅ `GOOGLE_SERVICE_INFO_BASE64` GitHub Secret set | 7 more GitHub Secrets |
| ✅ iOS source compiles 0 warnings 0 errors on iOS 26 SDK | App Store Connect listing |
| ✅ CI green at https://github.com/aarshps/varisankya-ios/actions | TestFlight upload |

---

## Stage A — Generate signing materials (~10 min, no Mac required)

> You do **not** need a Mac for this. OpenSSL on Windows / Linux / WSL works.

```bash
# 1. Generate the private key + CSR (run from repo root)
./scripts/generate_csr.sh aarshps@gmail.com "Varisankya Distribution" IN "Adarsh P S"
#    Outputs: Varisankya-key.pem (KEEP SECRET) + Varisankya.csr
```

**Web steps:**

1. Open https://developer.apple.com/account/resources/certificates/add — I can drive this for you with Playwright once enrollment is approved
2. Choose **Apple Distribution** → Continue
3. Upload `Varisankya.csr`
4. Click Continue, then Download → save as `distribution.cer` next to the CSR

```bash
# 2. Pack the cert + private key into a .p12 ready for GitHub Secrets
./scripts/pack_p12.sh distribution.cer
#    Outputs: Varisankya-Distribution.p12 + .p12.base64
#    Prompts for a password — pick a strong one, remember it.
```

```bash
# 3. Upload to GitHub Secrets
gh secret set BUILD_CERTIFICATE_BASE64 < Varisankya-Distribution.p12.base64
gh secret set P12_PASSWORD             # paste the password you chose above
```

**Back up `Varisankya-Distribution.p12` + password to a password manager.**
The cert is valid one year. If lost, you regenerate — no Apple charge.

---

## Stage B — Register the App ID (~3 min)

Visit https://developer.apple.com/account/resources/identifiers/list → **+ Add**.

| Field | Value |
| --- | --- |
| Type | **App IDs** |
| Sub-type | **App** |
| Description | `Varisankya` |
| Bundle ID | **Explicit** → `com.hora.varisankya` |
| Capabilities (tick) | ☑ Push Notifications, ☑ Sign In with Apple |

Click Register.

> I can drive this whole form for you via Playwright — say "drive App ID setup".

---

## Stage C — Create the Provisioning Profile (~2 min)

Visit https://developer.apple.com/account/resources/profiles/add.

| Field | Value |
| --- | --- |
| Distribution type | **App Store Connect** → Continue |
| App ID | `com.hora.varisankya` |
| Certificate | the Apple Distribution cert you just created |
| Name | `Varisankya AppStore` (**exact spelling matters** — `.github/workflows/ios-release.yml` references this name) |

Generate → Download → save as `Varisankya_AppStore.mobileprovision`.

```bash
# Add to GitHub Secrets
base64 -w0 < Varisankya_AppStore.mobileprovision | gh secret set PROVISIONING_PROFILE_BASE64
```

---

## Stage D — Generate App Store Connect API key (~3 min)

Visit https://appstoreconnect.apple.com/access/integrations/api/users.

1. Click **Generate API Key** (or "+" if the page is empty)
2. Name: `Varisankya CI`
3. Access: **Developer** (minimum needed for IPA upload)
4. Click Generate
5. **Download** the `.p8` private key (one-time download — back it up)
6. Note the **Key ID** (10 chars) and the **Issuer ID** (UUID at the top of the page)

```bash
# Add to GitHub Secrets
gh secret set APPLE_TEAM_ID         # paste 10-char team ID from developer.apple.com/account#MembershipDetailsCard
gh secret set APPLE_API_ISSUER_ID   # paste UUID from above
gh secret set APPLE_API_KEY_ID      # paste 10-char Key ID from above
base64 -w0 < AuthKey_XXXXXXXXXX.p8 | gh secret set APPLE_API_KEY_BASE64
gh secret set KEYCHAIN_PASSWORD     # any strong random string; CI uses it only inside its temp keychain
```

---

## Stage E — Verify all secrets are set

```bash
./scripts/check_apple_secrets.sh
```

You should see:
```
  [SET]     APPLE_TEAM_ID
  [SET]     APPLE_API_ISSUER_ID
  [SET]     APPLE_API_KEY_ID
  [SET]     APPLE_API_KEY_BASE64
  [SET]     BUILD_CERTIFICATE_BASE64
  [SET]     P12_PASSWORD
  [SET]     PROVISIONING_PROFILE_BASE64
  [SET]     KEYCHAIN_PASSWORD
  [SET]     GOOGLE_SERVICE_INFO_BASE64

All 9 secrets are set. You can trigger ios-release.
```

---

## Stage F — Create the App Store Connect listing (~10 min)

Visit https://appstoreconnect.apple.com → **Apps → + → New App**.

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | `Varisankya` |
| Primary language | English (U.S.) |
| Bundle ID | pick `com.hora.varisankya - Varisankya` |
| SKU | `varisankya-ios` |
| User Access | Full Access |

Then fill:

- **App Information** → use copy from `METADATA.md` (subtitle, promo text, description)
- **Pricing** → Free, all territories
- **App Privacy** → fill from `PRIVACY_LABELS.md`
- **Age Rating** → complete questionnaire (likely 4+)

> I can drive the entire listing form via Playwright — say "drive App Store Connect listing".

---

## Stage G — Trigger the release workflow

```bash
gh workflow run ios-release.yml -f track=testflight -f bump_build=true
gh run watch
```

~14 minutes later, the IPA appears in App Store Connect → **TestFlight → Builds**
in "Processing" state. Apple takes another ~5-10 min to scan it for bad symbols.

Once it shows "Ready to Submit":
1. Add **Test Information** (what to test + reviewer sign-in credentials)
2. Create an **internal testing group** (you yourself counts as an internal tester)
3. Install via TestFlight on your iPhone, smoke-test sign-in + add subscription + mark paid

---

## Stage H — Submit for App Store review

1. In App Store Connect, the **Version** (`3.8`) appears under the app's App Store tab
2. Select the TestFlight build you just verified
3. Add screenshots (see `SCREENSHOTS.md`)
4. Confirm metadata + reviewer credentials (`METADATA.md`)
5. **Save → Add for Review → Submit for Review**
6. Apple review: typically 24-48h, occasionally up to 7 days

On approval, the app goes live within a few hours.

---

## Things that will trip you up (preempted)

- **Sign in with Apple is mandatory** because the app offers Google Sign-In (Guideline 4.8). Already wired — don't remove the Apple button.
- **Privacy labels must be exhaustive** including Firebase Analytics. Use `PRIVACY_LABELS.md` verbatim.
- **Account deletion** is required (5.1.1(v)). Already wired in Settings → Delete account.
- **Reviewer test credentials** must work. Don't use your personal account — create a test Google account.
- **App icon**: CI currently generates a placeholder via `scripts/generate_icon.swift`. Replace `Varisankya/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` with a designed 1024×1024 PNG before submission.

---

## When something goes wrong

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| CI fails at "Restore signing assets" | Wrong P12_PASSWORD | Re-run `scripts/pack_p12.sh` carefully |
| CI fails at archive: "no signing identity matches" | Cert not in keychain | Confirm BUILD_CERTIFICATE_BASE64 is the .p12, not the .cer |
| CI fails at altool upload: 401 Unauthorized | API key wrong / no perms | Verify Issuer ID + Key ID + .p8 are all from the same row at App Store Connect Integrations |
| Upload succeeds but build never appears in TestFlight | Bundle ID mismatch or provisioning profile wrong | Confirm App ID at developer.apple.com matches `com.hora.varisankya` |
| TestFlight rejection: ITMS-90683 missing usage description | Info.plist missing a required Usage string | Already covered: NSFaceIDUsageDescription, NSUserTrackingUsageDescription |
| TestFlight rejection: ITMS-90189 missing app icon | Placeholder icon detected | Replace with designed 1024×1024 PNG |
| App Review rejection: 4.8 | Sign in with Apple missing/broken | Test on physical device before submitting |
| App Review rejection: 5.1.1(v) | Account deletion broken | Test Settings → Delete account on TestFlight build |
