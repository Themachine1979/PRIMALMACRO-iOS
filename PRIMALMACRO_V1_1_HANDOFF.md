# PRIMALMACRO next iOS app update — version 1.1 source

**Source branch:** `feature/primalmacro-v1.1-combined`  
**Current public submission:** Apple version 1.0 waiting for review; this source branch does **not** replace it.

## Implemented

- Ages 13–17 can use food diary and see logged calories/protein/carbs/fat. Adult calorie targets, weight-loss/muscle-gain objectives and weight-progress chart are hidden in teen mode.
- Sign in with Apple remains.
- Email and password account registration, login, verification email, resend verification and password reset; uses Firebase Authentication and iOS Keychain for refresh credentials. Email sign-in is disabled until configured.
- Added 13+ declaration before new Apple/email account sign-in.
- Separate local diary storage per account and legacy Apple diary migration.
- StoreKit **Redeem Offer Code** button on the membership screen (sign in first); StoreKit transaction update listener.
- In-app email account deletion.
- Dedicated manual App Store v1.1 upload workflow in `codemagic.yaml`, requiring owner approval.
- GitHub Actions simulator compilation, pure Swift nutrition math tests and Cloudflare Worker tests.

## Website

A separate Cloudflare Pages direct-upload ZIP was prepared from the actual `PRIMALMACRO_Cloudflare_Pages_Ready.zip` source. Its 13+ messaging explicitly says the diary-only mode and new login are coming in a later release. It does not misleadingly claim version 1.0 supports minors.

## Mandatory setup before user testing

1. In [Firebase Console](https://console.firebase.google.com/), create a dedicated PRIMALMACRO project and enable Authentication > Email/Password; verify email templates and project settings.
2. Set `PM_FIREBASE_API_KEY` (Firebase public Web API key) in Codemagic environment group `primalmacro_scanner`.
3. Set `FIREBASE_PROJECT_ID` (Firebase project ID) as Cloudflare Worker variable in a **staging** scanner Worker, then deploy the updated Worker source there. Do not change the live scanner without testing.
4. Run Codemagic's iOS compile check and signed TestFlight build from `feature/primalmacro-v1.1-combined`.
5. Test registration, age 13 and 17, age 18, email verification, sign in/out, restore purchases, password reset, account deletion, scanner sessions and existing Apple subscribers.
6. Review age-rating questionnaire, age-related privacy statements, marketing material and App Store subscription handling. Version 1.0's review should remain undisturbed.
7. Only after version 1.0 is approved, create new App Store version 1.1 in App Store Connect. The manual v1.1 upload workflow requires explicit approval and a fresh build number.

## **Release blocker — external offer redemptions**

The app displays Apple's official offer-code sheet, and StoreKit recognises its resulting transaction. **However**, a code redeemed via App Store or Apple redemption URL may create a transaction without an `appAccountToken`. The scanner Worker currently requires an active transaction linked to the signed-in account. Until a secure, ownership-verified, one-time transaction-to-account association using Apple's App Store Server API is implemented and tested, do **not** give out the planned `PRIMAL20` promotional codes. A redeemed code may unlock the diary but not AI scanning.

Apple documents [Set App Account Token](https://developer.apple.com/documentation/appstoreserverapi/set-app-account-token) for purchases made outside an app. Server changes must validate cryptographic proof and prevent cross-account hijacking.

## Other sign-off items

- Validate Apple's Sign in with Apple account-deletion/revocation behavior before release. Email-account deletion alone does not cover all accounts.
- For younger users, ensure compliance with relevant UK privacy standards, review children's data in Firebase and update the published privacy notice **before** email login and teen diary mode go live.
- A GitHub Actions simulator build is useful but is not a signed IPA, TestFlight test, live Cloudflare deployment or Apple review approval.

**Do not merge to public release until the blockers are resolved and signed builds are tested.**
