# App Store Privacy Nutrition Labels

Fill these in App Store Connect → **App Privacy** for `com.hora.varisankya`.
Mirror this table exactly — Apple cross-checks against what they observe in
review.

## Does the app collect data? **Yes.**

## Categories

### Identifiers
- **User ID** — collected, linked to user, used for **App Functionality**
  (Firestore documents are keyed by Firebase Auth UID).
  - Source: Firebase Auth.
  - Shared with: Google (Firebase).

### Contact info
- **Email address** — collected, linked to user, used for **App Functionality**
  (Firebase Auth account identification).
  - Source: Sign in with Apple or Google Sign-In.
  - Shared with: Google (Firebase).

### Purchases
- Not collected.

### Financial info
- **Other financial info** — collected, linked to user, used for **App
  Functionality** (subscription amounts and payment dates the user enters
  manually).
  - Source: User input.
  - Shared with: Google (Firebase Firestore — user's own private collection).
- We do **not** access bank accounts, cards, or payment processors. Amounts
  are values the user types into a text field.

### Usage data
- **Product interaction** — collected, **not linked to user**, used for
  **Analytics** (Firebase Analytics events: which buttons get tapped, which
  flows are reached).
  - Source: App-internal instrumentation (`Services/Analytics.swift`).
  - Shared with: Google (Firebase Analytics).

### Diagnostics
- **Crash data** — collected via Firebase Crashlytics if you enable it. The
  current build does **not** include Crashlytics; if you add it later, update
  this row.
- **Performance data** — same as above.

### Sensitive info, contacts, browsing history, search history, health, fitness, location, photos, audio, customer support
- **Not collected.**

## Tracking
- **The app does NOT track users across apps and websites owned by other
  companies.** Set this to "No tracking" in App Store Connect.

## Third-party SDKs declared
- Firebase iOS SDK (Auth, Firestore, Analytics).
- Google Sign-In iOS SDK.

Both are listed in `project.yml` and reproducibly downloaded by Swift Package
Manager during the build — no other SDKs are bundled.
