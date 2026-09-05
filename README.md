# Pantomina - Money Manager for Two

Shared finance for exactly two people — **Fern** (payer) and **Stark** (contributor) as system ids; display names are yours.

**Stack:** SwiftUI + SwiftData · iPhone only · paid App Store download · no network for ledger data (PostHog diagnostics later, PII firewall)  
**Spec:** [`APP_SPEC.md`](APP_SPEC.md) · **Decisions:** [`docs/DECISIONS.md`](docs/DECISIONS.md) · **Phase 7 PRD:** [`docs/phase-7-prd.md`](docs/phase-7-prd.md) · **ASC checklist:** [`docs/app-store-checklist.md`](docs/app-store-checklist.md)

## Status

**Phase 4 complete** — Slice A (Forecast/Checklist) · B (funding) · C (Cookie Jar).  
**Phase 5 complete** — A Baggage/loans · B War Chest funds/raids · C Snowball (queue, Sweep, Park From, stash labels).  
**Phase 6 complete** — A Snapshot/Empire · B charts+hybrid hero · C Year So Far (Fern·Stark·Household + history year window) / drift / Money Sleeps.  
**Phase 7** — Slice A shipped: offline capture parser + Add confirmation cards (`docs/phase-7-prd.md`). Rooms B/C artboards later. Home last-cycle note parked after Phase 7.  
**Phase 4 Slice C** — Cookie Jar running balance, who’s-paid, borrow return; jar Add locks Petty Cash + Just mine.  
**Phase 4 Slice B** — funding + Count it; Keep Doing Add/Edit/Delete + Category; twin PruLife.  
**Phase 4 Slice A** — Projection / Forecast / Checklist; recurring rules.  
**Receipts hygiene** — swipe Edit / Delete; contributions amount-only Edit.  
Phase 3 — allocations & settlement, Love Tab, Bills split + Fern share; Statement day cycle pick.  
Phase 2 — realization engine, TBD drawer, Statement day.  
Phase 1 — identity, seed CoA/accounts, onboarding, Receipts filters, Add entry, Settings rename.

## Run

Open `Pantomina.xcodeproj` in Xcode (or regenerate with `xcodegen generate` from `project.yml`), select **Pantomina-Preprod**, run on an iPhone Simulator (iOS 17.6+).

First launch: **Shall we dance?** (three steps: names + PHP chip, roles, optional starters). Then Home, Receipts, Add (sheet from the center tab), More → Accounts (pockets and categories) or The Fine Print (names).

```bash
xcodegen generate
xcodebuild -scheme Pantomina-Preprod -destination 'platform=iOS Simulator,name=iPhone 16' test
```

### Product notes (Phase 1)

- Add date field is labeled **When it happened** (salary/transfers too — not “purchase”).
- Input bounds: display name ≤40, pet ≤24, note ≤200; amounts **₱1…₱100,000,000**; snowball order/batch **1…99**.
- Status chips say **Not counted yet** (never `pending`/`realized` raw values); scopes say **Shared** / person names.
- Fonts: **Fraunces** + **DM Sans** (bundled under `Pantomina/Resources/Fonts/`).
- Delete the app from the Simulator to re-run onboarding (no Settings replay yet).

## Prototype (reference only)

`pantomina-app.jsx` + optional Vite host are **not** the product.

```bash
npm install && npm run dev   # optional; throwaway
```
