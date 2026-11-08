# PRIMALMACRO — iOS TestFlight & App Store checklist

- [ ] Register a **new bundle identifier** for PRIMALMACRO under the existing Apple Developer account.
- [ ] Create a **separate** PRIMALMACRO app record in App Store Connect (not the metrology app).
- [ ] Replace `uk.example.primalmacro` in both Xcode target configurations.
- [ ] Select the Apple Team and provisioning profile in the build service.
- [ ] Build the shared `PRIMALMACRO` scheme for iOS 17+ and install through TestFlight.
- [ ] Verify camera permission text and PhotosPicker selection on a real iPhone.
- [ ] Verify onboarding values, date handling, dietary estimates, meal deletion and app relaunch persistence.
- [ ] Verify menu/packaging photography with legible and illegible labels; correct wrong values before storing.
- [ ] Deploy the scanner Worker with separate secrets; never place server keys in the app or ZIP.
- [ ] Add per-user backend access and server rate limiting before public access (current secret token is for private testing).
- [ ] Publish an accurate privacy policy at a real HTTPS URL and complete App Privacy labels in App Store Connect.
- [ ] Describe weight and food information, photo uploads to Cloudflare/OpenAI, and any third-party processing truthfully.
- [ ] Have a qualified reviewer assess claims about dietary targets, and avoid presenting results as medical guidance.
- [ ] Add real screenshots captured from a running iPhone build (concept poster is only marketing inspiration).
- [ ] Verify working support contact, terms, final app name and relevant trademark clearance.
- [ ] Consider accessibility labels, Dynamic Type, VoiceOver, contrasts and localisation before wider release.
- [ ] Test offline diary operation and connection failures, plus data deletion and keychain handling.
