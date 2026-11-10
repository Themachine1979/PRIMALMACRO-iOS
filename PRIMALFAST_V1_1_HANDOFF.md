# PRIMALFAST — version 1.1 development handoff

**Branch:** \`feature/primalmacro-v1.1-combined\`  
**Pull request:** #3 (draft)  
**Release policy:** Do **not** merge, upload, or submit to Apple automatically. Version 1.0 review is unchanged.

## Implemented in the iOS source

- New adult-only **Fast** tab. Ages 13–17 retain the diary/scanner and cannot see or start fasting. Existing weight charts remain available via **Plan > Weight progress**.
- PrimalFast retains PRIMALMACRO's black/orange branding. The educational ring stages use cyan, orange, purple and green icons.
- Choose 12:12, 14:10, 16:8, 18:6, 20:4, or set an hour between 12 and 20; tap **Start Fast**.
- Live timer uses the recorded start timestamp (not an in-memory counter); survives app restarts and displays the goal completion and remaining time.
- Four clearly labelled **educational** stages at 0, 4, 12 and 16 hours: glucose for fuel, fat as fuel, ketones as fuel, and cellular recovery research. Marker times are general guideposts, not measurements of ketosis, fat oxidation or autophagy. The app does not claim that biological thresholds have been reached.
- Finishing/ending a fast records actual duration and whether the selected goal was reached. A recent history of up to seven ended fasts is shown.
- Optional local iPhone notifications at two hours remaining and goal completion, if authorised, with cancellation on early ending, sign out or disabling notifications.
- Fasting and reminder preferences are saved alongside the member's **separate local diary**, without changing the existing Apple/Firebase login or offer-code components. Older saved diaries are decoded with no fasting history.

## Required before release

1. Run the existing iOS simulator GitHub Actions or Codemagic **compile-check** workflow on this branch. This implementation was committed through GitHub, not compiled or signed on an iPhone here.
2. On an iPhone, verify 12, 16 and 18-hour fast selection, app suspend/resume, relaunch, goal reached, manual early stop, start another fast and recorded history.
3. Confirm notification permission denied/allowed, two-hour and completion reminders, early-end cancellation, and switching between two signed-in accounts.
4. Check ages 13, 17 and 18, changing an adult profile to under 18, and that the diary/scan/weight screens continue working. Age gating uses the current profile's self-reported age.
5. Verify an existing 1.0 member's diary survives upgrading to v1.1 and that signed-in users cannot read each other's local diaries.
6. Resolve v1.1 login and subscription release blockers in \`PRIMALMACRO_V1_1_HANDOFF.md\`: Firebase settings, real TestFlight testing, external Apple offer redemption account linkage, Sign in with Apple revocation/account deletion, privacy/age review.
7. Have the owner select an **unused App Store build number** and explicitly approve a Codemagic upload only after the above tests pass. The owner will submit v1.1 for review after v1.0 approval.

## User-facing safety

Fasting features are adult-only, voluntary and not medical guidance. The milestone icons reflect elapsed time and offer explanations of possible biological changes; they do not determine metabolic state from a phone timer. The app does not automatically extend fasts or encourage users to ignore symptoms. Users can end a fast whenever they wish.

No server/database changes or new subscription product are required for the local timer itself.
