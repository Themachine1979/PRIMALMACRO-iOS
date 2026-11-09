# PRIMALMACRO email + password work (next release, NOT public v1.0)

**Branch:** `feature/redeem-codes-email-accounts`

## What is implemented on the development branch

- Apple sign-in remains available.
- Email/password sign-up and sign-in screens with Firebase Authentication REST API.
- Registration requests a Firebase email-verification link. Unverified accounts cannot create a backend scanner session.
- Password reset email (Firebase). Firebase, not the app or Worker, handles passwords.
- Firebase refresh token is stored in iOS Keychain, not UserDefaults.
- Scanner Worker checks Google's Firebase JWT signature, audience, issuer, expiry and `email_verified` before issuing a 1-hour scanner session. A verified active Apple StoreKit subscription is still required for each AI scan.
- Separate on-device diaries for each signed-in user. A legacy diary may migrate for the previous Sign in with Apple user.
- Email account deletion from the Plan tab; local diary deletion for that email identity.
- StoreKit offer-code redemption button using the iOS 17-compatible sheet.

## Owner setup (not yet configured)

1. Create/choose a dedicated project in [Firebase Console](https://console.firebase.google.com/). Enable **Authentication → Sign-in method → Email/Password**.
2. Check **Authentication → Templates** for verification and password reset emails; verify sending-domain and delivery requirements.
3. In Firebase Project settings, find the project's **Web API key**. Add it to the existing Codemagic environment group `primalmacro_scanner` as `PM_FIREBASE_API_KEY`. This is a public client identifier; do not put an administrative Firebase service account key in the app.
4. Add the Firebase **Project ID** to the Cloudflare Worker's environment as `FIREBASE_PROJECT_ID`. The backend must run the updated `backend/src/access.js` and `backend/src/worker.js` to accept `POST /email/session`. Do **not** deploy development changes into the existing production scanner before staging tests.
5. Run Codemagic **iOS compile check** from this feature branch; address compiler errors before signed TestFlight testing.
6. Test registration, verification, login, wrong password, password reset, subscription purchase, subscription restoration, expiry and account deletion using TestFlight + a staging Worker.
7. Review privacy-policy and App Store privacy disclosures to include Firebase authentication and verified email addresses.

## Release-blocking gaps

**Do not merge or distribute as a release yet.**

- **Offer-code entitlement link:** An offer redeemed in the App Store may have no `appAccountToken`. The existing scanner deliberately rejects those transactions. Implement and test a secure proof-of-purchase and one-to-one mapping before calling Apple **Set App Account Token** (PUT `/inApps/v1/transactions/{originalTransactionId}/appAccountToken`). Never accept a client-supplied transaction ID alone as proof or overwrite another customer's link.
- **Apple account deletion:** Verify compliance with Apple's Sign in with Apple token revocation requirement; deleting an email login does not cover Apple identity tokens.
- **Account lifecycle:** After Firebase account deletion, already-issued scanner sessions may remain usable for up to 1 hour. Consider immediate per-account token revocation before public release.
- **Data isolation:** Diaries are **local to this device**, not synced across iPhones; communicate this clearly.
- **Production verification:** App Store subscriptions, server-side purchase checks, offer codes and scanner all require real-device end-to-end testing. A code commit is not proof of a successful signed build.

## Current submission

**App Store version 1.0 is unchanged.** This branch does not change the app build already Waiting for Review.
