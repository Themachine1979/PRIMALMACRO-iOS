# PRIMALMACRO privacy disclosure — DRAFT (not legal advice)

**Replace all bracketed placeholders and review with the actual production architecture before publishing.**

PRIMALMACRO is a nutrition tracking application for adults. Its profile includes a selected resting-calorie formula, age, height, weight, activity level and fitness goal. Meals and weigh-ins are stored locally within the app's private application storage on the device. PRIMALMACRO uses Sign in with Apple and StoreKit for membership. Profile and diary records are stored per installation.

When users explicitly request an AI photo scan, the selected photograph (a meal, a menu or packaging) is sent from the device to the operator's Cloudflare Worker. The Worker forwards the image to OpenAI for nutrition analysis. This upload does not occur for ordinary diary use. The operator should review the applicable Cloudflare and OpenAI data processing terms, retention policies, privacy notice obligations and data protection law before deployment.

The app stores the Apple user identifier locally. When a user confirms Apple sign-in for scanning, the Worker verifies the Apple token and issues a short-lived session that the app keeps in Keychain. The Worker sends the original StoreKit transaction ID to Apple to verify membership. Cloudflare stores short-lived replay records, daily scan counters and an aggregate lifetime counter. The OpenAI API key stays in Cloudflare.

The user may delete individual entries or remove the local profile, diary and weight records in **Plan → Delete all local data**. Signing out clears the scanner session from the device. Apple manages subscriptions separately.

Contact: **[COMPANY / OPERATOR CONTACT]**  
Privacy policy URL: **[REAL PUBLIC HTTPS URL]**  
Effective date: **[DATE]**  
Controller and jurisdiction: **[OPERATOR DETAILS]**

This draft must be updated if analytics, subscriptions, social accounts, HealthKit, barcode lookup, cloud storage, or public user authentication are introduced.
