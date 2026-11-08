# PRIMALMACRO iOS v0.2 — Apple Sign-in + StoreKit launch checklist

This release is a new iOS TestFlight build. Google login is **not** included.

## Customer experience

1. Branded PRIMALMACRO welcome/paywall screen on first launch.
2. Monthly and yearly plan choices, displaying prices returned by Apple StoreKit.
3. **Sign in with Apple** (no Gmail or Google requirement).
4. 14-day free trial **only if configured in App Store Connect and eligible according to Apple**.
5. Subscribe or Restore Purchases; verified active StoreKit subscription unlocks onboarding and tracker.
6. AI scanner uses the URL bundled at build time. Customers never enter API keys or tokens.

## App Store Connect actions required (owner)

1. Open PRIMALMACRO in App Store Connect.
2. Under Monetization > Subscriptions, create one subscription group: PRIMALMACRO Premium.
3. Create *auto-renewable* subscriptions in the **same group**:
   - Monthly: `uk.themachine1979.primalmacro.monthly`
   - Yearly: `uk.themachine1979.primalmacro.yearly`
4. Use **United Kingdom as the base storefront** and set the selected launch prices:
   - Monthly: **£5.99 per month** (duration: 1 Month).
   - Yearly: **£49.99 per year** (duration: 1 Year).
   - Savings for yearly vs twelve monthly payments: approximately **30.5%**.
   - These are owner-approved UK prices only; the app intentionally fetches the real storefront price via StoreKit rather than embedding a currency amount.
   - Create each product's subscription availability, localisation, and required App Review metadata.
5. Configure an introductory offer **Free Trial, 2 Weeks** for each plan where allowed. Apple limits trial eligibility across the group.
6. For TestFlight / sandbox, product availability can take time to propagate. Do not promise prices until StoreKit returns them.

## Apple capability / certificate actions

The project includes `PRIMALMACRO/PRIMALMACRO.entitlements` for Sign in with Apple.
- In Apple Developer, edit the PRIMALMACRO App ID `uk.themachine1979.primalmacro` and enable **Sign in with Apple**.
- Regenerate the PRIMALMACRO App Store provisioning profile to include that capability.
- Replace the old PRIMALMACRO profile in Codemagic code-signing identities. Leave the unrelated Quality Suite profile and certificate unchanged.

## Owner-only AI backend activation (internal beta)

This version does **not** embed the OpenAI key.
- Deploy the `backend/` Cloudflare Worker.
- Add `OPENAI_API_KEY` as a Cloudflare secret (never to GitHub or the app).
- The Worker is disabled by default: `BETA_SCANS_ENABLED = "false"`.
- Only for a *small, monitored TestFlight beta*, enable the flag temporarily and deploy with the included Cloudflare rate-limit binding.
- In **Codemagic → PRIMALMACRO-iOS → Environment variables**, set `PM_SCANNER_URL` to the deployed full HTTPS Worker URL ending in `/scan`.
- Start a **new** signed workflow build to inject that address into generated app Info.plist.
- In the iPhone app, scanning then uses the configured service automatically.

**Important:** The IP-based limiter is approximate and is NOT login, quota enforcement, or App Store subscription verification. Before inviting public customers, the backend needs server-verified identity + subscription entitlement, per-user quotas, global cost controls and abuse protection. Never make an unprotected OpenAI-funded endpoint publicly available.

## Validation and release notes

- Google Sign-In is deliberately deferred. No Google SDK is required in the Xcode project.
- The app locally checks the Sign in with Apple credential state, but a real account backend must cryptographically verify identity tokens before relying on them to authorise server requests.
- No price is hardcoded. Trial wording only appears when the selected product has a 2-week free trial *and* StoreKit says the customer is eligible.
- Subscriptions are handled by StoreKit, not custom card processing.
- Signed build 2 uses the new entitlement; updated Apple provisioning is required.
- Source changes are prepared, but a successful new Xcode compile and live StoreKit/Apple sign-in/AI scan **have not yet been verified**.
- Capture real screenshots and add Privacy Policy, Support URL and account deletion flow as applicable before App Store public review.
