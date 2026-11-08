# PRIMALMACRO privacy disclosure — DRAFT (not legal advice)

**Replace all bracketed placeholders and review with the actual production architecture before publishing.**

PRIMALMACRO is a nutrition tracking application for adults. Its profile includes a selected resting-calorie formula, age, height, weight, activity level and fitness goal. Meals and weigh-ins are stored locally within the app's private application storage on the device. In this prototype there are no user accounts, shared profiles or cross-device sync.

When users explicitly request an AI photo scan, the selected photograph (a meal, a menu or packaging) is sent from the device to the operator's Cloudflare Worker. The Worker forwards the image to OpenAI for nutrition analysis. This upload does not occur for ordinary diary use. The operator should review the applicable Cloudflare and OpenAI data processing terms, retention policies, privacy notice obligations and data protection law before deployment.

PRIMALMACRO stores a private scanner-access token in the iOS Keychain. The OpenAI API key is never stored on the iPhone.

The user may delete locally stored food entries individually and delete all local profile, diary and weight records in **Plan → Delete all local data**. Current v0.1 behaviour does not automatically erase the scanner Keychain token when deleting profile data, and any remote service retention obligations must be handled separately.

Contact: **[COMPANY / OPERATOR CONTACT]**  
Privacy policy URL: **[REAL PUBLIC HTTPS URL]**  
Effective date: **[DATE]**  
Controller and jurisdiction: **[OPERATOR DETAILS]**

This draft must be updated if analytics, subscriptions, social accounts, HealthKit, barcode lookup, cloud storage, or public user authentication are introduced.
