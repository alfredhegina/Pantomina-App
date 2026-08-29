# Next iPhone App Playbook

**Last Updated:** August 29, 2026  
**Purpose:** What to copy from Uswag into a second iPhone-only app, and what actually shortened the path from first build to App Store listing.  
**Status:** Recommendations only. Do not extract a shared Swift package yet.

Uswag already locked the expensive stack: Swift + SwiftUI, MVVM, SwiftData on-device, iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), iOS 17.6+, almost no third-party code (PostHog via SPM + StoreKit 2). A second iPhone-only app should copy that architecture. Do not restart in React Native, Flutter, or UIKit. Do not extract `UswagKit` until two apps are live and copy-paste actually hurts.

Treat Uswag as a **pattern library**, not a dependency. Copying about 15 files into a new Xcode project is faster than a shared package, and it keeps RPG brand and domain out of the next product.

**Sources:** [design doc §14 Decision Log](uswag-design-doc_8.md), [build phases](build-phases.md), [App Store checklist](app-store-checklist.md), live listing [Uswag - Life RPG](https://apps.apple.com/us/app/uswag-life-rpg/id6799418645).

---

## Stack to keep

| Layer | Decision | Notes |
|---|---|---|
| Language / UI | Swift + SwiftUI | UIKit only for nav/tab appearance, haptics, color bridging |
| Architecture | MVVM + `@Observable` | Feature Views → ViewModels → SwiftData / Services |
| Persistence | SwiftData, on-device | Offline-first. No backend for v1 unless the product requires one |
| Min iOS | **17.6** | Project setting; docs often say 17.0+ |
| Device | iPhone only | Set at project create. Universal binaries force 13" iPad screenshots |
| Packages | SPM in Xcode | Uswag has **one** remote package: PostHog iOS ≥ 3.69.5. No CocoaPods, no `Package.swift` |
| Monetization | StoreKit 2 | No RevenueCat. Entitlement = active sub **or** lifetime |
| Analytics | PostHog | Optional; no PII in event payloads. Copy `AnalyticsSecrets.example.swift` |
| CI | Xcode Cloud → TestFlight | Design intent; not required on day one |

There is no shared framework module in this repo. Reuse means copying folders and patterns.

---

## What to copy (then rename)

### Folder layout

```
App/                 # entry, ContentView, navigation, Environment
Models/              # SwiftData @Model types + StringLimit
ViewModels/          # one VM per feature
Views/<Feature>/     # screens
Views/Components/    # generic chrome only
Services/            # Keychain, analytics, network, settings
Monetization/        # only if freemium
Resources/Design/    # Colors, Typography, Spacing, Animation, ButtonStyle
Utilities/           # HapticManager
```

New GitHub repo. Do not put the second product inside this tree.

### App shell

| File | What to take |
|---|---|
| [App/UswagApp.swift](App/UswagApp.swift) | `@main`, nav/tab appearance, `ModelContainer`, optional first-launch gate |
| [App/ContentView.swift](App/ContentView.swift) | `TabView` + environment injection + paywall sheet |
| [App/AppNavigationState.swift](App/AppNavigationState.swift) | Tab enum + cross-tab deep links |
| [App/Environment.swift](App/Environment.swift) | Dev / Staging / Prod, `debugLog`, `FeatureFlags`, `AppVersion`, `LegalURLs` |
| [xcode-environment-setup.md](xcode-environment-setup.md) | Debug / Staging / Release + three schemes |

Rename `Uswag` / `uswag` / bundle IDs (`com.heginaholdings.<name>`, plus `.dev` / `.staging` if you want side-by-side installs).

### Design tokens (structure, not Uswag’s look)

Copy the files. Swap hex and fonts.

| File | Role |
|---|---|
| [Resources/Design/Colors.swift](Resources/Design/Colors.swift) | `Color.uswag` → your namespace; keep token names (`background`, `textPrimary`, `success`) |
| [Resources/Design/Typography.swift](Resources/Design/Typography.swift) | Type scale |
| [Resources/Design/Spacing.swift](Resources/Design/Spacing.swift) | Spacing + corner radius |
| [Resources/Design/ButtonStyle.swift](Resources/Design/ButtonStyle.swift) | Press styles + Reduce Motion |
| [Resources/Design/Animation.swift](Resources/Design/Animation.swift) | Shared springs |

Do not keep gold-as-sacred-XP or Cinzel unless the new product is also a dark RPG. Rank-tier metals stay in Uswag. Spec: [design-system.md](design-system.md).

### Generic UI and services

| File | Role |
|---|---|
| [Utilities/HapticManager.swift](Utilities/HapticManager.swift) | Impact / notification / selection |
| [Services/NetworkMonitor.swift](Services/NetworkMonitor.swift) | Offline gating |
| [Services/KeychainService.swift](Services/KeychainService.swift) | Change `com.uswag.*` key names |
| [Services/AnalyticsService.swift](Services/AnalyticsService.swift) + `AnalyticsSecrets.example.swift` | PostHog wrapper |
| [Services/AppSettings.swift](Services/AppSettings.swift) | UserDefaults wrapper |
| [Services/SoundService.swift](Services/SoundService.swift) | Toggleable sounds (if you need them) |
| [Models/StringLimit.swift](Models/StringLimit.swift) + [Views/Components/FieldLengthViews.swift](Views/Components/FieldLengthViews.swift) | Per-field caps. Use `.limitingText` (`onChange`). Binding-only clamp leaves extra letters on screen |
| [Views/Components/UndoToast.swift](Views/Components/UndoToast.swift) | Undo after destructive / instant actions |
| [Views/Components/SectionHeader.swift](Views/Components/SectionHeader.swift) | Section titles |
| [Views/Components/StatusPill.swift](Views/Components/StatusPill.swift) | Status chips |
| [Views/Components/EmojiPickerSheet.swift](Views/Components/EmojiPickerSheet.swift) | Emoji pickers |
| [Views/Components/UswagCard.swift](Views/Components/UswagCard.swift) | Card chrome; rename and restyle |

Notification services (`TreasuryNotificationService`, `InventoryNotificationService`) are local-notification scaffolding. Rewrite payloads; do not copy treasury/inventory copy.

### Monetization (if the next app is freemium)

| File | Role |
|---|---|
| [Monetization/EntitlementStore.swift](Monetization/EntitlementStore.swift) | StoreKit 2 entitlements |
| [Monetization/PlanLimits.swift](Monetization/PlanLimits.swift) | Free vs Pro caps |
| [Monetization/PaywallView.swift](Monetization/PaywallView.swift) | Paywall UX |
| [Monetization/ProBadge.swift](Monetization/ProBadge.swift) | Pro chrome |
| `Config/USWAG.storekit` | Local catalog for Dev/Staging |

Replace `uswag.pro.*` product IDs. Keep the product rule: Free is reduced capacity of the **same** system; Pro never exceeds design-doc ceilings; present the paywall at the cap instead of a silent disabled + or "Failed to create."

Xcode rewrites `.storekit` paths (`../../Config/...`). Keep a file that path can actually resolve, or local `Product.products` returns empty.

### Docs to duplicate as templates

| Uswag file | Use as |
|---|---|
| [uswag-design-doc_8.md](uswag-design-doc_8.md) §14 | Design doc with a **Decision Log + Why** |
| [build-phases.md](build-phases.md) | Ship-order table with a skip rule |
| [app-store-checklist.md](app-store-checklist.md) | TestFlight → ASC → listing |
| [../.cursor/marketing/asc-version-1.0-metadata.md](../.cursor/marketing/asc-version-1.0-metadata.md) | Paste-ready Description / Keywords / Review notes |
| [../.cursor/marketing/screenshot-brief.md](../.cursor/marketing/screenshot-brief.md) | Locked ASO verb/desc **before** generating frames |
| [../.cursor/rules/uswag-update-docs-with-code.mdc](../.cursor/rules/uswag-update-docs-with-code.mdc) | Same-pass docs with code |

### Cursor skills that already paid off

- **Greenlight** — pre-submit store policy scan (caught a "Coming Soon" placeholder)
- **aso-appstore-screenshots** — `compose.py` outputs 1290×2796; pair with a Dev/Staging-only screenshot seeder compiled out of Production
- **Humanizer** — listing copy
- **Impeccable** — design pass only; it is not the app framework

---

## What not to copy

- Domain: Character, Role, Skill, Quest, XP, ranks, Treasury, Inventory, Gemini roast prompts
- Visual world: mentor-desk charcoal, gold reserved for XP, Filipino rank metals
- Age gate / Gemini compliance unless the new app also uses a consumer AI API
- Sign in with Apple — still unfinished in Uswag; do not copy a half-auth story
- A shared SPM package named after Uswag
- `.entitlements` — Uswag does not have one yet. Add only when the new app needs Sign in with Apple or extra capabilities
- `PrivacyInfo.xcprivacy` as-is — write a new privacy manifest for whatever the new app actually collects

---

## How to start (in Xcode)

1. New iOS App: Swift, SwiftUI, SwiftData, **iPhone only**, deployment **17.6**, bundle `com.heginaholdings.<name>`.
2. Duplicate the folder layout. Copy the shell files above. Rename tokens and namespaces.
3. Add Debug / Staging / Release + three schemes. Follow [xcode-environment-setup.md](xcode-environment-setup.md).
4. Write a 2-page design doc first: one-sentence product, iPhone-only, offline-first yes/no, monetization, and a Decision Log row for each lock.
5. Ship a **manual core loop** before AI, IAP polish, or a fifth tab. Uswag’s original strategy was functional without AI; Gemini was a power-up.
6. New GitHub repo.

---

## Retrospective: first build to App Store listing

Drawn from the May–August 2026 decision log, build phases, and the live listing. Repeat these. Do not rediscover them.

### Product and architecture (weeks saved)

- **Lock platform and storage on day one.** iOS native, SwiftData on-device, no backend, no multiplayer. Later features stayed cheap because the storage story never changed.
- **Write the design doc before the fifth screen.** Caps, empty states, and Why in §14 stopped re-arguing rank names, quest limits, and gold usage in chat.
- **Manual first, AI later.** The core loop shipped without a network. Gemini BYOK is optional; the app still works offline. Do not start the next app on an API.
- **iPhone-only as a product decision, not a last-week fix.** Universal binaries forced 13-inch iPad screenshots. Set `TARGETED_DEVICE_FAMILY = 1` when you create the project.
- **Freemium + StoreKit 2, not a paid download.** Category comps (Habitica, LifeForge) are free + subscription. Paid ₱299 would have fought discovery. Native StoreKit avoided RevenueCat and a backend.
- **Free = same product, smaller caps.** Paywall at the cap. Side quests and daily AI stayed ungated so Free still felt like the real app.
- **Gemini free tier over Claude.** Claude needed a card even for "free." BYOK + Keychain + age gate + plain-text attribution (no logo) unblocked AI without a partnership. Keep the legal risk on a list; do not scale BYOK without a lawyer.

### Build habits that cut decision time

- **Phases with a skip rule.** Original plan: TestFlight after the core loop; Treasury and Inventory after validation. When they shipped before 1.0, it was a conscious override with a Why, not silent scope creep.
- **Same-pass docs.** Code + build-phases bullet + decision-log row in one change. The next session did not have to reconstruct why gold is not on every CTA.
- **Dev / Staging / Prod from the start.** TestFlight uses Staging (`STAGING` flag). Feature flags that were Dev-only left beta with no motion. Gate on "not production" when beta should match shipping feel.
- **Demo seeder compiled out of Production.** Settings → Load screenshot demo lives only in DEBUG/STAGING. Recapture screenshots without contaminating the store binary.
- **Input caps and one stress test file.** Unbounded names overflowed SE-width layout; peso fields needed a ceiling. Port `StringLimit` plus a small input test on day one of any form-heavy app. See `UswagTests/InputStressTests.swift`.
- **Hit-testing and keyboard as a checklist.** `contentShape(Rectangle())`, `.buttonStyle(.borderless)` on Form chip rows, `.scrollDismissesKeyboard(.interactively)` on every add/edit sheet.

### App Store Connect (days saved, some learned the hard way)

Do these **before** the first archive you care about:

- Apple Developer Program, 2FA, Free Apps Agreement
- If IAP: **Paid Apps Agreement + banking + tax** before you need the paywall screenshot. The first auto-renewable group **must submit with a new app version**. Park products, then joint-submit app + monthly + yearly + lifetime
- Privacy nutrition labels and age rating drafted while you still remember what you collect (Uswag: Device ID + analytics; 17+ store / 18+ copy for Gemini)
- Privacy / Terms / Support URLs live on a simple site. ASC will not wait for a marketing redesign
- **Sign-in required: unchecked** if there is no account. Reviewers bounce on empty login fields

Screenshot and IAP traps Uswag already paid for:

- iPhone 6.7" frames are **1290×2796**. IAP App Review screenshots are that size, not 1024×1024 (1024 is promo only)
- Lock ASO verb/desc in a brief, then run `compose.py`. Do not invent headlines in App Store Connect
- Paste pack for Description / Keywords / Review notes so you do not rewrite under submission stress
- Greenlight scan before submit
- **Never reuse `CFBundleVersion`.** Local archives 13 and 14 burned numbers; the next store binary had to jump to 15. Bump only when you will upload, or keep a dedicated store build counter
- After 1.0 is live, the next upload is a **new marketing version** (1.0.1), not another build of 1.0
- Mac / Vision availability **off** unless you designed for them

TestFlight path that worked: Staging bundle (`….staging`) → external beta → Production app record only when listing assets were locked. Do not mix staging and prod bundle IDs.

### What still slowed Uswag (do not copy)

- iPad left enabled until ASC demanded 13" screenshots
- StoreKit catalog path rewritten by Xcode so local products loaded as zero
- IAP review screenshots uploaded as 1024 squares the first time
- Binding-only text clamps; cascade-delete on skills; silent disable at Free caps
- Sign in with Apple specified in the design doc and never shipped. Do not promise auth you will not build
- BYOK Gemini terms vs consumer apps: still an open legal item

---

## Suggested first week for app #2

| Day | Work |
|---|---|
| 1 | Xcode project, iPhone-only, three schemes, token files with a new palette |
| 2 | Design doc + Decision Log (name, one loop, caps, monetization yes/no) |
| 3–5 | One tab, one SwiftData model, add/edit/list, field limits |

When the loop is usable: Staging TestFlight, then paywall / screenshots / listing using the Uswag checklist as a **duplicate**, not as a shared framework.

Until there is a product name and the one thing version 1 does, the reusable framework is the **shell + this playbook**, not Uswag’s RPG.
