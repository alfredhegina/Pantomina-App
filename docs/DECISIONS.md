# Pantomina — decisions log

Living log of locked **Baseline** choices and parked **For later** work. The product spec is `APP_SPEC.md`. If this file and the spec disagree, stop and ask.

**How to use**

- **Baseline** — locked. Implement this way. Do not reopen unless a human explicitly says to.
- **For later** — parked. Do not scaffold, stub, or "just quickly add" these. A pointer in the UI ("someday") is allowed only where the spec already names one.
- New entries go at the bottom of the matching section, dated, with a one-line why.
- Status values: `baseline` · `for-later` · `superseded` (leave the old row; point to the new one).

---

## Baseline

| Date | Decision | Why |
|---|---|---|
| 2026-08-23 | Product is an **iOS App Store** app. Build and archive in **Xcode**, beta on **TestFlight**, release via **App Store Connect**. Not a PWA, not browser-only. | Stated ship path for this project. |
| 2026-08-23 | **iPhone-first.** Design and QA against a modern iPhone viewport with safe-area insets. | Spec layout is mobile-first iOS; iPad is For later. |
| 2026-08-23 | UI stays **Vite + React 18 + TypeScript + Tailwind + restyled shadcn + Recharts + Phosphor**. Native shell is **Capacitor** (`ios/` Xcode project). Not SwiftUI, not React Native, for MVP. | Spec UI (shadcn, Recharts, web Phosphor) is DOM. Capacitor produces an `.ipa` without rewriting the design system. |
| 2026-08-23 | Persistence is **SQLite on device** via Capacitor. **IndexedDB / Dexie is not the store of record.** | iOS can evict WKWebView web storage. This is a finance ledger. Supersedes the v2.2 Dexie line in the spec. |
| 2026-08-23 | **Local-first, single-device MVP.** Sync is Phase 8 only. | Spec §6 / §8. |
| 2026-08-23 | Optional Gemini API key lives in the **iOS Keychain**. Never in SQLite, JSON backups, logs, or screenshots. | App Store + finance-app hygiene. |
| 2026-08-23 | Capture from **iOS Shortcuts / App Intents** into the unconfirmed-entries inbox (same parse pipeline as in-app chat). Not a public webhook. | Native equivalent of the spec's Shortcut door. |
| 2026-08-23 | Backups use the **iOS share sheet / Files / document picker**. Cadence is checked on **open and foreground**, plus manual "Back up now." Do not depend on background fetch as the only trigger. | iOS background work is opportunistic; a missed backup of a ledger is unacceptable. |
| 2026-08-23 | Engine work is **test-first** (Vitest, Superpowers TDD). UI consumes `src/engine` and does not reimplement rules. | Spec §6–§7. |
| 2026-08-23 | Installed design/method skills (Taste, Impeccable, Emil Kowalski, UI UX Pro Max, Superpowers) inform UI/UX and process. **`APP_SPEC.md` + this file win** if a skill conflicts (e.g. skill wants Inter/dark mode/confetti; spec forbids them). | Skills are taste and method, not product law. |
| 2026-08-23 | Spec visual direction stays **Soft UI Evolution** on warm paper: Fraunces + DM Sans, sage/terracotta, light mode only, cheese quarantine. Skills may refine craft; they may not replace the system. | Spec §1–§2. |
| 2026-08-23 | For **product UI** (ledger, bills, sheets), prefer **Impeccable, UI UX Pro Max, Emil (`emil-design-eng` / `apple-design` / `animate`), and Taste `high-end-visual-design`**. Taste `design-taste-frontend` is landing-page oriented — use it for marketing/onboarding polish only, not for data tables. | Taste v2 SKILL.md explicitly excludes dashboards and multi-step product UI. |

## For later

Do not implement until a human moves the row to Baseline.

| Date | Item | Notes |
|---|---|---|
| 2026-08-23 | Android / Play Store | Capacitor can add `android/` later; do not add the project now. |
| 2026-08-23 | iPad, landscape, Split View, Stage Manager | iPhone-only until then. |
| 2026-08-23 | Minimum iOS version, bundle ID, Team ID, signing, App Store category copy, screenshots, privacy nutrition labels | Set when the Xcode project and Apple Developer account are wired. Draft category: Finance. |
| 2026-08-23 | Face ID / passcode lock on open | Nice for a ledger; not MVP. |
| 2026-08-23 | Home Screen widgets, Live Activities, Apple Watch, Lock Screen | Native surfaces beyond the Capacitor WebView. |
| 2026-08-23 | iCloud Drive as a backup destination / CloudKit | Phase 8 is still the named sync path (Supabase). Revisit CloudKit vs Supabase then; do not pick a second sync now. |
| 2026-08-23 | Push / local notifications for cycle due, checklist leftover, Love Tab nudge | Easy to nag; spec forbids nagging. Design copy first if this is ever opened. |
| 2026-08-23 | BGTaskScheduler for backups | Unreliable; on-open cadence is Baseline. |
| 2026-08-23 | Dark mode | Spec is light mode only. |
| 2026-08-23 | Web / desktop companion | App Store is the product. |
| 2026-08-23 | React Native / Expo / SwiftUI rewrite | Only if Capacitor + WKWebView fails App Review or performance. |
| 2026-08-23 | Household-scoped funds | Spec: personal-scope in MVP. |
| 2026-08-23 | Swappable payer / contributor roles | Spec §7.9. |
| 2026-08-23 | Third person / family seat | Spec §7.1. |
| 2026-08-23 | Currency other than PHP | Spec §2. |
| 2026-08-23 | Impeccable `buildPath` (comp-first vs code-first), `/impeccable init` PRODUCT.md/DESIGN.md, and the Impeccable **before-edit hook** | Skill files are installed; the hook was not. Run `npx impeccable install --providers=cursor --scope=project` if you want live detectors. Do not invent a second design system before Phase 0. |
| 2026-08-23 | App Review edge cases (export compliance, account deletion, support URL) | Handle when first TestFlight/App Store listing is prepared. |

## Instructions to the agent

1. Read `APP_SPEC.md` and this file at the start of a phase.
2. If a request matches a For-later row, refuse the implementation and offer to reopen the decision instead.
3. When a human makes a new call, append a dated row here in the same session — do not leave it only in chat.
4. Superseded baselines stay in the table with `superseded` in the Decision cell and a pointer to the replacement.

## Installed skills (2026-08-23)

Project-local. Cursor reads `.cursor/skills/` (symlinks into `.agents/skills/` where the CLI copied payloads). Spec + this file still win on conflict.

| Source | What landed | Use for |
|---|---|---|
| [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | Taste family (`design-taste-frontend`, `high-end-visual-design`, image-gen, etc.) | Visual craft. Product screens: `high-end-visual-design`. Landing/onboarding: `design-taste-frontend`. |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | `.cursor/skills/impeccable` | Shape, critique, polish, iOS-aware audit. Hook not installed. |
| [emilkowalski/skills](https://github.com/emilkowalski/skills) | `emil-design-eng`, `animate`, `apple-design`, `write-swift`, … | Motion, Apple HIG translation, sheets. |
| [obra/superpowers](https://github.com/obra/superpowers) | TDD, plans, debugging, review | Engine work and phase execution. |
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | `.cursor/skills/ui-ux-pro-max` (+ design/brand helpers) | Searchable UI styles, UX rules, stack notes (React, Capacitor/iOS). |

Refresh Taste / Emil / Superpowers with `npx skills update -p -y`. Refresh UI UX Pro Max with `npx ui-ux-pro-max-cli update`. Impeccable: copy from upstream or `npx impeccable install --providers=cursor --scope=project` (installs the hook too).

