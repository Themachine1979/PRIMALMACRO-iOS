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

## Codemagic

1. Run `primalmacro-ios-check` on the PR branch. It runs the Swift nutrition test, Node Worker tests and unsigned simulator build.
2. Set `PM_BUILD_NUMBER` to an unused number higher than the latest PRIMALMACRO 0.2.0 build. Optionally set `PM_SCANNER_URL` to the approved sandbox HTTPS URL ending in `/scan`. An empty URL leaves scanning unavailable.
3. Start `primalmacro-ios-testflight` manually with the updated PRIMALMACRO profile and `PRIMALMACRO Codemagic` integration. It exports an internal-testing-only IPA as an artifact. After approval, upload the IPA with Transporter and assign it to the intended internal TestFlight group. The workflow has no upload or publishing step.

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
