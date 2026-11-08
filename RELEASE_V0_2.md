# PRIMALMACRO v0.2 TestFlight release

## Apple owner actions

1. Confirm the PRIMALMACRO app record uses bundle ID `uk.themachine1979.primalmacro`. Enable Sign in with Apple on that App ID and regenerate the App Store provisioning profile for Codemagic.
2. Create both auto-renewable products in one PRIMALMACRO Premium subscription group. Use the United Kingdom as the base storefront.

   | Product ID | Duration | UK price |
   | --- | --- | --- |
   | `uk.themachine1979.primalmacro.monthly` | One month | £5.99 |
   | `uk.themachine1979.primalmacro.yearly` | One year | £49.99 |

3. Configure a two-week free introductory offer for both products and complete availability, localisation and review metadata. StoreKit supplies the storefront price and confirms trial eligibility. Google login is deferred.
4. For scanner testing, obtain the App Store Server API in-app purchase key, key ID and issuer ID. Keep these in Cloudflare.

## TestFlight v0.2 build 11 findings (2026-11-08)

- The iPhone welcome screen renders and Sign in with Apple presents successfully. Sign out appears after authentication, but the app still requires a **verified StoreKit subscription** before opening the tracker.
- Both monthly and yearly prices currently display as **Unavailable** because StoreKit did not return the configured product identifiers. This is not corrected by adding another login method. Check that the products exist in App Store Connect, are in one subscription group, have matching IDs and durations, UK prices, availability, localisation, metadata, and eligible 2-week introductory offers. Verify the Paid Apps Agreement and subscription status. After changing metadata, allow sandbox propagation before retesting.
- Commit `670a048` lets testers choose monthly or yearly even when prices are pending; the Subscribe button remains disabled until real StoreKit products load. This fix requires a **new** build to appear on iPhone.
- An email/password account option was requested as a future addition. Implement it only with a trustworthy hosted identity provider, email verification, secure reset/recovery, privacy/deletion controls, and server-side entitlement validation. Do **not** store passwords locally, emulate logins, or grant premium access without verified Apple subscription. Apple login remains the only working identity method until a backend is configured.
- AI scanning is **not yet live**. A deployed Cloudflare backend, owner-approved sandbox secrets, configured `PM_SCANNER_URL`, test-linked Apple purchase, and explicit `SCANS_ENABLED` approval are required. Do not activate OpenAI billing or public AI scanning by default.
- Before claiming success, verify actual StoreKit product retrieval, purchase/trial via a sandbox TestFlight account, entry into tracker, then a safe closed-beta scan against the Worker. No steps here authorize deployment or uploads.

## Codemagic

1. Run `primalmacro-ios-check` on the PR branch. It runs the Swift nutrition test, Node Worker tests and unsigned simulator build.
2. When starting the signed workflow, enter a positive whole build number higher than the latest PRIMALMACRO 0.2.0 build in App Store Connect. Optionally set `PM_SCANNER_URL` to the approved sandbox HTTPS URL ending in `/scan`. An empty URL leaves scanning unavailable.
3. The existing `primalmacro-ios-testflight` workflow remains **build-only**: it exports an internal-testing-only IPA artifact without uploading it.
4. A separate `primalmacro-ios-upload-internal` workflow is available for **explicitly approved uploads**. To use it, start it manually on `release/v0.2-testflight`, enter an unused build number (higher than build 10 if no other 0.2.0 build has been uploaded), and tick `I approve uploading this newly built IPA to App Store Connect`. Without that checkbox, the workflow exits before building or uploading. No scheduled or push triggers are configured.
5. The upload workflow builds a **new internal-testing-only IPA** and uses the existing `PRIMALMACRO Codemagic` integration. Its `publishing.app_store_connect` block uploads the IPA to App Store Connect with both `submit_to_testflight: false` and `submit_to_app_store: false`. These flags mean **no automatic TestFlight beta-review submission and no App Store-review submission**, not "disable the IPA upload." After Apple processes the build, the owner manually assigns it to the appropriate internal tester group in App Store Connect.
6. Do not run the upload workflow until the owner deliberately approves the upload. It does not deploy Cloudflare or enable paid AI scanning.

[Codemagic internal TestFlight setup](https://docs.codemagic.io/yaml-publishing/app-store-connect/)

## Cloudflare and AI activation

1. Keep the committed `SCANS_ENABLED = "false"` and any previous beta endpoint disabled. Use a dedicated sandbox Worker with `APP_STORE_ENVIRONMENT = "Sandbox"` for TestFlight. Review the SQLite Durable Object migration, rate-limit binding and budget variables.
2. Add Worker secrets `SESSION_SECRET` (32 random bytes encoded as base64url or hex), `APP_STORE_PRIVATE_KEY` (full .p8), `APP_STORE_KEY_ID`, `APP_STORE_ISSUER_ID` and `OPENAI_API_KEY`. Use a restricted OpenAI project key and review model access, usage alerts and billing. Keep request bodies and credentials out of logs. Enable scanning only after the owner approves a controlled sandbox test.
3. The Worker verifies Apple's RS256 identity signature, audience, issuer, expiry and a single-use five-minute challenge, then issues a 24-hour Keychain session. Each scan checks current subscription status, product, expiry, revocation, environment and the app account token against the App Store Server API. The Worker trusts transaction fields received directly from Apple's authenticated HTTPS endpoint and accepts no client-supplied transaction payload.
4. A per-IP and per-member throttle limits short bursts. One Durable Object atomically reserves 3 attempts per member per UTC day, 25 globally per UTC day and 100 total by default. Failed and timed-out OpenAI attempts still consume a slot. The Worker pins the model and limits each request to one image, about 2.8 MB of request data and 1,400 completion tokens. These are usage limits. Provider charges depend on model pricing and other usage on the OpenAI project. Keep one budget namespace per deployment and review costs before raising the limits.
5. Purchases made in this build pass an app account token to StoreKit. Existing purchases without it still work for the local tracker. AI requires a linked purchase. Use a fresh sandbox purchase and establish an owner-controlled migration plan before enabling AI for legacy subscribers. Family-shared, billing-retry and grace-period purchases do not grant scanner access in this release.

[Apple identity verification](https://developer.apple.com/documentation/signinwithapple/verifying-a-user) · [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi) · [Durable Object storage](https://developers.cloudflare.com/durable-objects/best-practices/access-durable-objects-storage/)

## Validation

- Six Worker tests passed on Node 24 with mocked Apple and OpenAI endpoints. They cover disabled configuration, signature and claim checks, forged sessions, nonce replay, wrong-account and revoked or expired entitlements, bounded request bodies, concurrent quota enforcement and a successful scan response.
- Wrangler 4 dry run bundled the Worker, Durable Object and rate-limit binding with scans disabled.
- Static parsing passed for the Swift sources, Xcode project, property lists, Wrangler TOML and Codemagic YAML.
- This Windows host has no Swift compiler or Xcode. Run the Codemagic nutrition and simulator compile checks before signing. IPA generation, live Apple login, subscription products and trial eligibility, physical-device layout and a live scan remain unverified.
- Internal acceptance should cover a small iPhone and a current notched or Dynamic Island model with large text, both UK prices, fresh and previously subscribed sandbox accounts, purchase cancellation, restore and refund or expiry. Check full-screen camera cancellation, all photo modes, manual diary fallback, scanner session expiry and quota exhaustion.

## Public release gates

Complete device acceptance, privacy and support links, and Apple privacy disclosures. Confirm the applicable account deletion and Apple access revocation flow and resolve legacy subscriber migration if needed. Production requires separately approved Apple and Cloudflare configuration, production transaction verification, and an approved AI budget.
