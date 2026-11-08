# PRIMALMACRO — Native iPhone Fitness & Nutrition Tracker

**Version:** 0.1.0 (source prototype)  
**Platform:** iOS 17+ · SwiftUI · native Xcode project  
**Project:** `PRIMALMACRO.xcodeproj` · shared build scheme `PRIMALMACRO`  
**Brand:** black + volcanic orange + gorilla icon

This is a **new and separate iOS app**, not a modification of any existing metrology / Quality Suite app. The `branding/` folder includes the approved visual direction. The app uses those colours and the icon, but the concept poster is not a pixel-perfect screenshot of the compiled program.

## What's built

| Area | Available in the iOS source |
|---|---|
| Onboarding | BMR formula sex option, adult age, height, body weight, activity, goal |
| Daily plan | Mifflin–St Jeor resting energy, activity-adjusted maintenance, goal-based calorie target and macros |
| Home | Calorie ring, calories remaining, protein/carbs/fat cards, meals, scan shortcut |
| Food diary | Breakfast/lunch/dinner/snacks, date picker, editable manual or AI-reviewed entries, delete |
| Progress | Weight logging, latest change, Swift Charts trend, historical entries |
| Photo scanner | Camera and photo library; 3 modes: food, menu, packaging |
| AI estimate review | Food name, serving, calories, protein, carbs, fat, fibre, confidence and notes; review/edit before saving |
| Settings | Edit goal/profile, scanner endpoint and token, erase local diary/profile |
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

## Configure AI scanning (Cloudflare Workers)

The app deliberately has **no API keys built in**. The food diary, calculator and weight tracking function without AI, but photo recognition will stay disabled until the scanner is configured.

On a Windows machine with Node.js:

```powershell
cd backend
npm install
npx wrangler login
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put PRIMAL_ACCESS_TOKEN
npm run deploy
```

- Enter your **OpenAI API key** when prompted for `OPENAI_API_KEY` (it is not shared with the iPhone).
- For `PRIMAL_ACCESS_TOKEN`, use a strong separate random secret. One way to create one on a PC with Python is `python -c "import secrets; print(secrets.token_urlsafe(32))"`. Save a copy in your password manager so you can enter the same token on your own iPhone.
- Copy the Workers HTTPS URL printed by deployment and add `/scan` to the end (for example `https://primalmacro-scanner.YOUR-SUBDOMAIN.workers.dev/scan`).
- In PRIMALMACRO on iPhone: **Plan → Configure AI scanner**, paste the full `/scan` URL and the private access token. The access token is stored in the iOS Keychain.
- You can check `https://...workers.dev/health` in a browser; it responds with a basic service status but does **not** prove your OpenAI credentials work. Test with an actual meal/photo in the app.

**Security for a public launch:** The included token gate is suitable for private testing with a secret that only you possess. Before releasing the app to public users, replace this single shared bearer-token approach with per-user authentication, server-side rate limits, quotas, misuse protection and a robust cost-control policy. Do not hardcode the shared token in a published app. Never expose the OpenAI API key in an iOS binary or public Git repo. Images are sent to your Cloudflare Worker and onward to OpenAI only after you press **ANALYSE WITH AI**.

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

Upload this project's ZIP to your iOS build website, then tell me the **website/service name** and any output/error it gives. We can adapt its signing or import instructions without touching the existing metrology app.
