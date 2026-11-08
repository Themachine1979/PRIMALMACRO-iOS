# PRIMALMACRO — Native iPhone Fitness & Nutrition Tracker

**Version:** 0.2.0 (Apple-only membership prototype; not yet device-tested)  
**Platform:** iOS 17+ · SwiftUI · native Xcode project  
**Project:** `PRIMALMACRO.xcodeproj` · shared build scheme `PRIMALMACRO`  
**Brand:** black + volcanic orange + gorilla icon

**Latest setup instructions: [RELEASE_V0_2.md](RELEASE_V0_2.md)**. The old v0.1 instructions below are historical where they differ.

This is a **new and separate iOS app**, not a modification of any existing metrology / Quality Suite app. The `branding/` folder includes the approved visual direction. The app uses those colours and the icon, but the concept poster is not a pixel-perfect screenshot of the compiled program.

## What's built

| Area | Available in the iOS source |
|---|---|
| Apple membership | Apple-only sign-in, a StoreKit monthly/yearly selector and Restore Purchases; 14-day trial shown only when Apple says eligible |
| Onboarding | BMR formula sex option, adult age, height, body weight, activity, goal |
| Daily plan | Mifflin–St Jeor resting energy, activity-adjusted maintenance, goal-based calorie target and macros |
| Home | Calorie ring, calories remaining, protein/carbs/fat cards, meals, scan shortcut |
| Food diary | Breakfast/lunch/dinner/snacks, date picker, editable manual or AI-reviewed entries, delete |
| Progress | Weight logging, latest change, Swift Charts trend, historical entries |
| Photo scanner | Camera and photo library; 3 modes: food, menu, packaging |
| AI estimate review | Food name, serving, calories, protein, carbs, fat, fibre, confidence and notes; review/edit before saving |
| Settings | Edit goal/profile, manage Apple subscription, sign out, erase local diary/profile |
| Privacy | Diary kept in iOS application storage; API access token in Keychain; OpenAI key only on the Cloudflare Worker |

**What is not yet done:** A signed `.ipa`, real-device acceptance testing, App Store submission, HealthKit, barcode-specific scanning, subscription billing, user accounts or cross-device synchronisation. A **live** AI scan requires you to deploy the included Worker and supply your own OpenAI API key. No live OpenAI call was performed while developing this package.

## Build this with your iOS/Xcode build website

1. Extract this ZIP without changing the internal folder structure.
2. Upload/import the **entire project folder**, or `PRIMALMACRO.xcodeproj` with its adjacent `PRIMALMACRO/` directory, to your build service. Some services accept a GitHub repository instead of a ZIP.
3. Select scheme **PRIMALMACRO**, configuration **Release**, iOS deployment target **17.0**, platform **iPhone**.
4. In project build settings, replace the **placeholder** bundle ID `uk.example.primalmacro` with a unique ID you own, e.g. `uk.yourcompany.primalmacro`.
5. Select your existing Apple Developer team (but **do not** reuse the metrology app's bundle identifier).
6. Let the build service create/sign an iOS app archive or `.ipa`. Register the same new bundle ID as a **new** app in App Store Connect and upload your build for TestFlight.
7. Test onboarding, photo import, camera permission, local diary persistence, weight logging, scanner connectivity, and deleting data on your real iPhone.

**If the website asks for a special project format or output:** share the website name; this package is a normal Xcode project, not Expo or React Native.

### Native project layout

```text
PRIMALMACRO.xcodeproj/         actual Xcode project + shared scheme
PRIMALMACRO/                  SwiftUI application source
  PrimalMacroApp.swift
  Models.swift / NutritionMath.swift / AppStore.swift
  OnboardingView.swift / MainTabView.swift / HomeView.swift
  DiaryView.swift / FoodEditorView.swift
  ScannerView.swift / ScanClient.swift / ScannerSettingsView.swift
  ProgressView.swift / PlanView.swift / Design.swift
  Resources/Assets.xcassets/   iOS icon and brand image
backend/                      Cloudflare Worker for protected photo analysis
branding/                     approved concept art and icon
APP_STORE_CHECKLIST.md        release preparation notes
PRIVACY_DRAFT.md              editable privacy disclosures
```

No third-party Swift packages or CocoaPods are required for the iPhone app.

## AI scanner: automatic for customers

The new scanner no longer asks customers to type an API key, URL, or access token. The developer deploys `backend/` and configures a *public service address* in Codemagic before creating a signed TestFlight build. The OpenAI key stays as a Cloudflare Worker secret.

For a **restricted internal beta only**:
1. Deploy the Cloudflare Worker from `backend/` and set the `OPENAI_API_KEY` secret in Cloudflare.
2. Enable `BETA_SCANS_ENABLED` temporarily in Wrangler only for monitored testing; it is OFF by default.
3. In Codemagic add the environment variable `PM_SCANNER_URL` with the HTTPS Worker URL ending in `/scan`. The signed-build workflow injects that non-secret URL into the app Info.plist.
4. Rebuild the signed iOS app and run real meal, menu and packaging tests.

The Worker uses approximate request rate limiting and **does not** yet verify Apple membership or enforce strict per-user/global AI quotas. Do not expose it to the general public until those controls are implemented. There are no customer-side scanner credentials.

## Membership setup

- Sign in with Apple is the only login in v0.2. Google login is deferred.
- Enable Sign in with Apple on the Apple Developer App ID and **regenerate the iOS App Store provisioning profile** to add the entitlement.
- Create monthly and yearly subscriptions in one App Store Connect subscription group with exact product IDs specified in `RELEASE_V0_2.md`.
- Set your own prices in App Store Connect. The app fetches the localized prices from Apple.
- Configure a **two-week free trial** for eligible customers in App Store Connect. SwiftUI does not invent trial eligibility.
- For public subscriptions, implement secure server-side account/subscription verification and an appropriate account deletion workflow. Local Apple login is for initial TestFlight integration.

### AI image behaviour

- **Food:** rough calorie/macro estimate; oils, recipe and portion are not known from pixels alone.
- **Menu:** returns up to five dishes as **individual choices**, not a total meal, and labels invented nutrition estimates as low-confidence.
- **Packaging:** extracts visible numbers and explicitly notes a per-100g basis when a serving size cannot be established.
- Every result goes through **Review & Add to Diary** so you can correct the portion or numbers before saving.

Do not use AI estimates for medical, allergy or dietary treatment decisions. Nutrition advice is for adults 18+ and is general guidance only.

## Calculation model

- BMR = `10 × weight_kg + 6.25 × height_cm − 5 × age + sex_coefficient` (male coefficient +5, female coefficient −161)
- Maintenance = BMR × activity multiplier (1.2, 1.375, 1.55, 1.725 or 1.9)
- Goal calorie starting point: maintenance − 400 kcal/day for fat loss, unchanged for maintenance, + 250 kcal/day for muscle gain; nearest 25 kcal with a general minimum of 1200 kcal. This is an estimate and not a prescription.
- Protein baseline: 1.8 g/kg for lose/gain or 1.4 g/kg for maintain; fats around 28% of calorie goal; carbs from remaining calories.

Profile changes immediately recalculate daily targets. Historical diary entries remain unchanged. Current body weight is updated when a weigh-in is logged.

## Validation performed

- Swift source syntactically parsed using Swift 6.2 on Linux.
- Standalone nutrition algorithm compiled and executed on Linux; BMR, target direction and macro tests passed.
- Backend `node --test` checks passed for health, rejected authentication, invalid mode, sanitising data, and authorised scan-response handling.
- `project.pbxproj` parsed successfully with `plutil`.
- PNG app icon verified at 1024×1024, RGB.

**Not verified here:** macOS Xcode compiler build, Apple code signing, physical-camera operation, a deployed Worker, real OpenAI photo recognition or App Store review. These require your Apple build pipeline and/or service credentials.

## Your next step

Follow [RELEASE_V0_2.md](RELEASE_V0_2.md) to configure Apple's Sign in with Apple capability, monthly/yearly subscription products and the owner's AI service before starting a new Codemagic TestFlight build.
