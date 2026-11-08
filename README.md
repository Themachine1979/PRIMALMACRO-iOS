# PRIMALMACRO — Native iPhone Fitness & Nutrition Tracker

**Version:** 0.2.0 (Apple-only TestFlight candidate)
**Platform:** iOS 17+ · SwiftUI · native Xcode project  
**Project:** `PRIMALMACRO.xcodeproj` · shared build scheme `PRIMALMACRO`  
**Brand:** black + volcanic orange + gorilla icon

**Latest setup instructions: [RELEASE_V0_2.md](RELEASE_V0_2.md)**. Use it for current Apple, Codemagic and Cloudflare setup.

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

Signed IPA generation and physical-device acceptance are pending. See [RELEASE_V0_2.md](RELEASE_V0_2.md) for the archive workflow and owner actions.

### Native project layout

```text
PRIMALMACRO.xcodeproj/         actual Xcode project + shared scheme
PRIMALMACRO/                  SwiftUI application source
  PrimalMacroApp.swift
  Models.swift / NutritionMath.swift / AppStore.swift
  OnboardingView.swift / MainTabView.swift / HomeView.swift
  DiaryView.swift / FoodEditorView.swift
  ScannerView.swift / ScanClient.swift
  ProgressView.swift / PlanView.swift / Design.swift
  Resources/Assets.xcassets/   iOS icon and brand image
backend/                      Cloudflare Worker for protected photo analysis
branding/                     approved concept art and icon
APP_STORE_CHECKLIST.md        release preparation notes
PRIVACY_DRAFT.md              editable privacy disclosures
```

No third-party Swift packages or CocoaPods are required for the iPhone app.

## Membership and AI scanning

Sign in with Apple is the only login. StoreKit supplies the localized monthly and yearly prices and determines trial eligibility. Customers confirm their Apple sign-in for AI access and choose which photo to analyse.

The Cloudflare Worker verifies Apple identity and checks for an active purchase linked to that identity before reserving scan quota. The app includes the service URL. Cloudflare holds the OpenAI key and the Worker ships with scans disabled. See the [release checklist](RELEASE_V0_2.md) for sandbox setup and production gates.

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

## Validation

See the [release checklist](RELEASE_V0_2.md#validation) for test results and remaining device checks.
