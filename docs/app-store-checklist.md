# App Store Publishing Checklist — Pantomina

**Status:** Not started — checklist template (paid download, no IAP).  
**Target:** App Store (iOS 17.6+, **iPhone only**)  
**Bundles:** Prod `pantomina.heginaholdings.com` · Preprod `pantomina.heginaholdings.com.preprod`  
**Last Updated:** August 29, 2026

---

## Progress Summary

| Milestone | Status |
|-----------|--------|
| Apple Developer Program | ☐ |
| **Paid Apps Agreement** + banking + tax | ☐ Required before first paid archive |
| Free Apps Agreement | ☐ |
| Preprod TestFlight app record | ☐ |
| Production app record | ☐ |
| PrivacyInfo.xcprivacy | ☐ |
| Greenlight preflight (app target) | ☐ |
| Devices iPhone only | ☐ `TARGETED_DEVICE_FAMILY = 1` |
| Screenshots 1290×2796 | ☐ Lock brief first — `.cursor/marketing/screenshot-brief.md` |
| App Store metadata paste | ☐ `.cursor/marketing/asc-version-1.0-metadata.md` |
| Nutrition labels (PostHog Device ID) | ☐ |
| Pricing (paid download) + Availability | ☐ Mac/Vision **off** |
| Sign-in required | ☐ **Unchecked** (no accounts) |
| Submit for App Review | ☐ |

---

## Before first serious archive

- [ ] Paid Apps Agreement active (legal entity + banking + tax)
- [ ] Privacy / Terms / Support URLs live
- [ ] Privacy nutrition labels drafted (analytics / diagnostics)
- [ ] Preprod scheme builds and installs side-by-side with Prod
- [ ] Demo seeder compiled out of Prod
- [ ] Never reuse `CFBundleVersion` on upload
- [ ] Greenlight scan on the Xcode app (exclude skill trees)
- [ ] No "coming soon" / placeholder user-facing strings

## Monetization note

Pantomina is a **paid App Store download**. There is no freemium tier and no StoreKit IAP for MVP. Do not copy Uswag paywall / product ID workflows.
