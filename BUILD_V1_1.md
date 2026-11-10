# PRIMALMACRO v1.1 — Build from Codemagic

**Source branch:** `feature/primalmacro-v1.1-combined`  
**Bundle ID:** `uk.themachine1979.primalmacro`  
**App version:** `1.1` (the native Xcode project and all three signed Codemagic workflows now agree)

## 1. First run the build check

1. Open Codemagic and select the connected **PRIMALMACRO-iOS** application.
2. Select branch `feature/primalmacro-v1.1-combined` (NOT `main` or `release/v0.2-testflight`).
3. Select workflow `primalmacro-ios-check` and start a build.
4. Confirm the nutrition and Worker tests and **iPhone simulator compile** pass.

A successful compile check is necessary, but does not prove that signing, App Store subscription products, Firebase, or AI scanning work.

## 2. Create a signed IPA without uploading it

1. Select workflow `primalmacro-ios-testflight`.
2. Select the same `feature/primalmacro-v1.1-combined` branch.
3. Enter an **unused positive build number**. Check App Store Connect first: a number used by a previous upload may be rejected.
4. Run the build. The result is an internal-testing-only IPA artifact. **This workflow does not upload to Apple.**

This workflow now explicitly sets `MARKETING_VERSION=1.1` and the chosen build number, instead of the old `0.2.0`.

## 3. Optional: upload a new internal TestFlight build

Only after a successful compile and signed build, select `primalmacro-ios-upload-internal` on the **same branch**, enter an unused build number, and explicitly tick the upload approval. The workflow creates a fresh internal-testing-only IPA and uploads it to App Store Connect; it does **not** submit the app for review. Assign internal testers in App Store Connect afterward.

The `primalmacro-ios-upload-appstore` workflow is separate and must **not** be used for a public v1.1 release until the release blockers below are cleared.

## Required configuration for working features

- **Original app logo**: unchanged. This build preparation changes no app images/assets.
- **Email/password**: configure Firebase Authentication (Email/Password) and put Firebase's *public Web API key* in Codemagic environment group `primalmacro_scanner` under `PM_FIREBASE_API_KEY`. Without this, email account buttons remain disabled.
- **AI scanner**: set `PM_SCANNER_URL` in the same Codemagic environment group to the approved HTTPS scanner endpoint ending in `/scan`. Without this, the scanner cannot connect.
- **Server for email sessions**: deploy and test the updated Worker on a **staging** Worker, with `FIREBASE_PROJECT_ID` set; do not overwrite the live scanner to experiment with v1.1.
- **Sign in with Apple**: App ID capability and up-to-date distribution provisioning profile must be configured in Apple and Codemagic.

## Release blockers (not build blockers)

These do **not** prevent a test IPA from being created, but they **do** prevent a responsible v1.1 public release:

1. Externally redeemed Apple subscription offer codes can lack an `appAccountToken`, causing AI entitlement verification to fail. Do not distribute `PRIMAL20` codes until verified ownership linking is implemented and tested.
2. Test Sign in with Apple account-deletion/revocation obligations and email account lifecycle.
3. Test UK children's privacy/age-rated disclosures and teen diary mode, and update published policy before release.
4. On a real TestFlight device, test subscription purchase, restoration, onboarding, email verification, 13–17 diary mode, and scanner authorization.
5. Verify App Store Connect's current v1.0 status before creating and submitting the public 1.1 version.

See `PRIMALMACRO_V1_1_HANDOFF.md` for details.
