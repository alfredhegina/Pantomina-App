# Skills review — remove / add / improve

**Date:** 2026-08-29  
**Target:** SwiftUI rebuild (human lock). Prototype = visual reference only.  
**Status:** **Approved** 2026-08-29 with amendment: stable person ids are **`fern` / `stark`** (not `larr` / `len`). Centavos integer money kept.

Skills run: Impeccable (Operate critique), Humanizer (sample copy), Greenlight (`preflight .`), ASO (benefit hypotheses), write-swift / apple-design (advisory).

---

## Remove

| Item | Why |
|---|---|
| Capacitor + React + Vite as **MVP ship path** | Human lock: SwiftUI. Supersede DECISIONS Baseline + SPEC §6 / §7.10 / cursor rule. |
| SQLite-via-Capacitor as store of record | Replace with **SwiftData** on device (same “won’t get WebView-evicted” intent). |
| Vitest / `src/engine` TypeScript as the engine home | Engines become pure Swift + Swift Testing/XCTest. |
| Promoting `pantomina-app.jsx` or the throwaway Vite host into production | Keep as reference; do not port float pesos / `you`/`partner` ids. |
| Freemium / StoreKit Paywall / EntitlementStore from Uswag | Paid App Store download only. |
| Uswag RPG domain, Cinzel/gold XP world | SPEC Soft UI / Fraunces+DM Sans / sage+terracotta. |
| Prototype string **“Edit entry — coming soon”** | Greenlight §2.1 App Completeness; never ship placeholders. |
| Shipping without `PrivacyInfo.xcprivacy` | Greenlight CRITICAL once an Xcode app exists (blocked until then). |
| Treating UI UX Pro Max “React/Capacitor stack notes” as product law | Skills inform craft; SPEC + new DECISIONS win. |

---

## Add

| Item | Why |
|---|---|
| Xcode iPhone-only app (17.6+), bundles `pantomina.heginaholdings.com` + `.preprod` | Ship path + side-by-side TestFlight. |
| Uswag-style shell (copy/rename): App, Environment, Design tokens, Keychain, Analytics, Haptics, StringLimit, UndoToast | Playbook ship habits; not domain. |
| PostHog iOS SDK + PII/ledger allowlist firewall | Monitoring for paying users. |
| Paid Apps Agreement / banking / tax on ASC checklist | Required for paid download. |
| `PrivacyInfo.xcprivacy` + privacy nutrition labels (PostHog Device ID) | Greenlight + ASC. |
| Privacy / Terms / Support URLs | ASC won’t wait. |
| Bundled Fraunces + DM Sans | SPEC type; register in Info.plist. |
| Swift Charts (or equivalent) for Empire / YTD / Love Tab | Recharts unavailable. |
| Engine module: `Centavo`/`Money`, `Cycle`, settlement pure functions — value types first (`write-swift`) | SPEC §7; test-first preserved. |
| Productization law in Swift: stored `baseName` + computed labels from `Person.name` | SPEC §3. |
| Preprod-only demo/fixture seeder | Screenshots without contaminating Prod. |
| Docs after approval: app-store checklist, ASC paste pack, screenshot brief, same-pass docs rule | Playbook habits. |
| Impeccable `PRODUCT.md` / iOS `DESIGN.md` (or equivalent) when Phase 0 starts | Operate-mode native brief; optional `/impeccable init`. |

---

## Improve

| Item | Why |
|---|---|
| SPEC §6 Phase 0 acceptance | Drop `cap sync` / Vitest / storybook route; accept: Swift cycle tests, Simulator launch, token primitives in SwiftUI, Reduce Motion. |
| SPEC delivery paragraph + `.cursor/rules/pantomina.mdc` | Say SwiftUI + SwiftData + Xcode, not Capacitor. |
| Prototype → rebuild map | Pet titles, 5-tab IA, Add sheet, Bills/Love Tab, Cookie Jar, War Chest — rebuild; fix ids to `fern`/`stark`, money to `Int` centavos. |
| Cheese copy (Humanizer) | Keep knowingly cheesy pet titles / empty “Nothing here yet. Rare quiet moment.” Soften or gate nudge tone like “say thank you” if it feels pushy; never cheese on amounts/errors. Toast “Saved. Team effort.” / “Added to the jar.” are fine. |
| Sheets / motion (apple-design + Emil) | Map prototype springs to SwiftUI interruptible sheets; honor Reduce Motion globally. |
| Greenlight scan scope | After Xcode exists, run on the app target; exclude `.agents/skills` noise (false “Android” / console.warn hits). |
| ASO (hypotheses only — no frames yet) | Candidate benefit lines: **Two of us, one ledger** · **Settle the cycle together** · **See the Love Tab clearly** · **Watch net worth climb** (negative-OK) · **Cookie Jar without shame**. Lock verb/desc in screenshot brief before `compose.py`. Avoid empty-state frames. |
| Onboarding “Shall we dance?” | Keep; Humanizer-pass final microcopy in Phase 1. |
| Gemini BYOK + age/compliance | Still Phase 7; copy Uswag *Keychain* pattern, not roast prompts; revisit Gemini consumer-app legal note. |
| README | Replace “Couple finance app” with SwiftUI ship pointer + SPEC link (after DECISIONS supersede). |

---

## Greenlight snapshot (2026-08-29)

Ran `greenlight preflight .` on current tree (no Xcode app yet):

- **CRITICAL:** No `PrivacyInfo.xcprivacy` — expected; add with Phase 0/1 app target.
- **WARN:** “Edit entry — coming soon” in prototype — do not carry into SwiftUI.
- **WARN/INFO:** Hits inside skill scripts — ignore for product; scope scans to the app later.

**Blocked until Xcode project exists:** entitlements, usage strings, real privacy manifest contents, IPA scan.

---

## Suggested next plan (after you approve)

1. Supersede Capacitor/React/SQLite-Capacitor in DECISIONS; lock SwiftUI + SwiftData + paid + PostHog + bundles + Preprod/Prod.  
2. Patch APP_SPEC §6 / §7.10 + cursor rule.  
3. Phase 0: new Xcode project, shell copy from Uswag, tokens, cycle engine tests, Simulator.  
4. Then feature phases 1–7 per SPEC (engines in Swift).

---

## Explicit non-changes

Product IA, bi-weekly cycle, Love Tab rules, cheese quarantine, two-person non-negotiables, PHP centavos, Phase feature order (1–8) stay. Only delivery stack and Phase 0 tooling change.

---

## Phase 3 polish (2026-08-29, pre–Phase 4)

Skills: Impeccable Operate, Humanizer, Emil / apple-design, UI UX Pro Max (mobile Operate).

| Before | After | Why |
|---|---|---|
| Fern card below CTAs; meta “Not a reverse Love Tab” | Settle → Fern covers → actions; shorter human captions | Read money, then act; cheese quarantine |
| Account picker subtitle `Statement` only | `Shared · Statement` / `Fern · Statement` | Household cards looked non-shared |
| Cycle menu only if 2+ anchors | Always when any anchors | Sep 15 statement cycle discoverable |
| Salary-only income seed | + **Income · Side hustle** (backfill) | Matches how people actually earn |

Next product phase: **Phase 4** (Forecast, Checklist, funding plans, Cookie Jar).

---

## Statement day cycle pick (2026-08-29)

Skills: Impeccable Operate, Emil / apple-design, Humanizer, UI UX Pro Max (mobile Operate). Smoke confirmed; shipped in `7e1cdb2`.

| Before | After | Why |
|---|---|---|
| Counts on = only stored `proposedRealizedDate`s | Cutoff-matching candidates ∪ proposals | Paper statement may not match auto guess |
| Pending list filtered by proposal | **All** pending for the card (“Still in the pile”) | Tick what’s on *this* statement; rest stay TBD |
| Header “On this statement” for whole pile | “Still in the pile” + “Guessed · …” when proposal ≠ Counts on | Operate honesty |
| Changing Counts on risked losing context | Keep ticks across cycle change; clear on **card** change | Interruptibility |
| Wanted to change Phase 2 `07/04→08/15` | Auto proposal **unchanged** | Spec acceptance fixture |

---

## Phase 4 skills critique (2026-08-29, pre-build)

Skills: Impeccable Operate, Humanizer, Emil / apple-design, UI UX Pro Max (mobile Operate). **Docs lock only — no Phase 4 product code in this pass.**

| Surface | Recommendation | Why |
|---|---|---|
| Bills IA | Four panes: The split · Forecast · The Checklist · The Love Tab; scrollable Seg / 44pt targets; no fifth tab | Spec §5; Operate density without cramming |
| Forecast / Checklist | Shared cycle picker (same language as Split) | One cycle mental model |
| Forecast | Verdict card first (breathing room / over + in − committed − variable); then Expected in / Committed with `DisplayLabels` reason chips; footer “Nothing here is booked yet.” | Scan money → lists; no engine nouns |
| Forecast “over” | Quiet link to fund-raid; copy that raid is **Phase 5** (pointer only) | For-later discipline; no raid engine now |
| Projected rows | Ghosted + **Projected** chip; never in actuals/settlement/YTD; exact = one-tap confirm, estimate = edit-then-confirm | Spec §4.5; cheese quarantine on chips |
| Checklist | Header “N of M paid · ₱X still to send”; tick = pay + realize; past-cutoff one gentle flag; CC task → Statement day via typed `NavigationLink` | Emil / AttributeGraph lesson |
| Funding plans | More → Things We Keep Doing (with rules) and/or Checklist tranche rows — **not** a fifth Bills pane; chips `funded k/n` → `paid`; Forecast charges tranche per cycle | Spec §4.9; distill Bills |
| Cookie Jar | More grid **The Cookie Jar**; running balance; borrows parenthesized; who’s-paid strip; filter by source; Love-Tab tone (visible, never nagged) | Spec §4.13; cheese on title only |
| Method | Pure engine modules + Swift Testing first; Phase 4 accept fixtures before chrome polish | Superpowers / write-swift |

### Explicit non-changes (Phase 4 skills)

Phase order 1–8; Love Tab floor-0; statement auto-proposal rule; person ids `fern`/`stark`; centavos; light mode + Fraunces/DM Sans. Fund raids / snowball / loans = Phase 5; Empire = Phase 6; chat Add = Phase 7.

---

## Phase 4 Slice A micro-pass (2026-08-29)

Shipped: engines + Bills Forecast/Checklist + read-only rules. Skills check: short Seg labels, shared cycle, no fake contribution, empty teach copy, estimate sheet, Projected filter. Next: Slice B funding.

## Bills + Receipts UI polish (2026-08-29)

Skills: Impeccable Operate, Humanizer, Emil. UI-only after Slice A.

| Surface | Change |
| --- | --- |
| Bills Seg | Equal-width tabs when ≤4 options (no sparse horizontal scroll) |
| Split | Log / Post CTAs stacked with `Spacing.md` under settle + Fern cards |
| Forecast | Shortfall tip in verdict card; stacked In / Committed / Typical variable; omit booked footer when lists exist; semibold row amounts |
| Receipts | People/scope row (All · names · Shared) + Filters sheet (Expense / Income / Pending / Projected); Filters · n when active |

Next product: Phase 4 Slice B (funding).

## Receipts hygiene — swipe Edit / Delete (2026-08-29)

Skills: Operate, Emil, Apple HIG. Before Slice B.

| Action | Behavior |
| --- | --- |
| Leading swipe | Edit → prefilled Add sheet; re-runs AllocationRouting + Realization; same `id` |
| Trailing swipe | Delete → confirm (“Remove from the pile?”); hard delete |
| Contribution rows | Edit → amount-only sheet; Delete with Bills confirm |
| Other settlementRole | Delete only; confirm “This was posted from Bills. Remove it?” |

**Paused here.** Next product when resumed: Phase 4 Slice B (funding).

## Phase 4 Slice B — funding (2026-08-30)

Skills: Operate, write-swift TDD. Spec §4.9.

| Piece | Behavior |
| --- | --- |
| Engine | `Funding` status funded k/n → paid; forecast charges tranche per cycle; exclude bill rule from committed |
| Checklist | **Set aside** tranche → ledger expense; last half auto-Paid; no Pay row |
| Things We Keep Doing | Pause; Add/Edit/Delete; **Category** required; validation error under title; Funding plans status |
| Seed | Twin personal PruLife (Fern 2×₱1,500, Stark 1×₱3,000); bare PruLife retired |

### Tranche ledger mini-pass (2026-08-30)

Skills: Operate, Humanizer. Tick = Counted expense + Funded k/n toast. Footer: each set-aside hits Receipts.

### Checklist pay method + add recurring (2026-08-30)

Skills: Operate, Humanizer, Emil.

| Piece | Lock |
| --- | --- |
| Count it | Prefills default account; **Change** for one-cycle override; Shared shows Just mine / 50·50 |
| Add rule | Whose Just Fern / Stark / Shared; **Category** required; optional 2-cycle set-aside |
| Edit / Delete | Swipe Edit (same sheet) / Delete+confirm; pause temporary; funding locked once a set-aside is counted |
| Validation | Error in first Form section (visible at medium detent) |
| Seed | PruLife · Fern (2×₱1,500) + PruLife · Stark (1×₱3,000); retire bare PruLife |
| Anti-double | Funded bills never post full amount; personal = just mine |

**Slice B complete** (funding + mini-slices). Next: Phase 4 Slice C (Cookie Jar).

## Phase 4 Slice C — Cookie Jar (2026-08-30)

Skills: Operate, Humanizer, write-swift TDD. Spec §4.13.

| Piece | Behavior |
| --- | --- |
| Engine | Running balance; unreturned borrow parenthesized / dips; returned nets out; who’s-paid; filter by source |
| More | **The Cookie Jar** — In the jar, Who’s paid chips, Still out + Returned, Statement |
| Add | Cookie Jar toggle → income / Spend·Borrow + optional source |
| Seed | Units 404/406/408/305 (₱700/mo expected) + demo statement rows |
| UX polish | Re-tap clears filter (no Clear ×); Returned confirm; jar-native **Add to the jar**; full bills on Receipts, unit shares = In |
| Add/Edit jar | Category locked **Petty Cash**; split locked **Just mine**; kind In/Spend/Borrow |

**Mental model:** Pay full internet/water on Receipts (Shared). Unit reimbursements → jar In with unit source. Spend/Borrow only for physical jar cash. Do **not** 50·50 jar In (would inflate Stark due).

**Phase 4 complete** (A+B+C). Next: Phase 5 (loans & funds).
