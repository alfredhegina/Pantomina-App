# Pantomina

Shared finance for exactly two people — **Fern** (payer) and **Stark** (contributor) as system ids; display names are yours.

**Stack:** SwiftUI + SwiftData · iPhone only · paid App Store download · no network for ledger data (PostHog diagnostics later, PII firewall)  
**Spec:** [`APP_SPEC.md`](APP_SPEC.md) · **Decisions:** [`docs/DECISIONS.md`](docs/DECISIONS.md) · **ASC checklist:** [`docs/app-store-checklist.md`](docs/app-store-checklist.md)

## Status

**Phase 3** — allocations & settlement, Love Tab, Bills split + Fern share; Statement day cycle pick.  
**Phase 4** — skills locked (Forecast, Checklist, funding, Cookie Jar); build next.  
Phase 2 — realization engine, TBD drawer, Statement day.  
Phase 1 — identity, seed CoA/accounts, onboarding, Receipts filters, Add entry, Settings rename.

## Run

Open `Pantomina.xcodeproj` in Xcode (or regenerate with `xcodegen generate` from `project.yml`), select **Pantomina-Preprod**, run on an iPhone Simulator (iOS 17.6+).

First launch: **Shall we dance?** Then Home, Receipts, Add (sheet from the center tab), More → The Fine Print.

```bash
xcodegen generate
xcodebuild -scheme Pantomina-Preprod -destination 'platform=iOS Simulator,name=iPhone 16' test
```

### Product notes (Phase 1)

- Add date field is labeled **When it happened** (salary/transfers too — not “purchase”).
- Input bounds: display name ≤40, pet ≤24, note ≤200; amounts **₱1…₱100,000,000**.
- Status chips say **Not counted yet** (never `pending`/`realized` raw values); scopes say **Shared** / person names.
- Fonts: **Fraunces** + **DM Sans** (bundled under `Pantomina/Resources/Fonts/`).
- Delete the app from the Simulator to re-run onboarding (no Settings replay yet).

## Prototype (reference only)

`pantomina-app.jsx` + optional Vite host are **not** the product.

```bash
npm install && npm run dev   # optional; throwaway
```
