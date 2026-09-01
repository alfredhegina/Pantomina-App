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

---

## Phase 5 skills critique (2026-08-30, pre-build)

Skills: Impeccable Operate, Humanizer, Emil / apple-design, UI UX Pro Max (mobile Operate), write-swift. **Docs lock — Slice A may start after this row.**

| Surface | Recommendation | Why / Push back |
|---|---|---|
| More IA | **Baggage We're Carrying** + **The War Chest** as first-class links (not under Fine Print). Footer: more rooms later. | Don’t invent a third “debts” room; Love Tab stays partner receivable |
| Baggage | Active list + archive (“Baggage we put down”); derived balance prominent; purpose + APR (0% distinct); journal dated notes; **no hand-typed balance** | Balance Day confirm = Phase 6 |
| War Chest | Fund cards: In the bank · owed-back · whole-again-at · target + IOU sliver; summary when owed | No household-scoped fund toggle (For later) |
| Raid | Sheet from Forecast over + War Chest; raid order; amount ≤ balance; **MVP absorb only** | No add-to-due in UI; engine retains attribution |
| Checklist loan | Emit `loan_payment`; Count it → ledger + `loanPayment` role + `paidMonths++` | No separate loan-pay screen |
| Snowball | War Chest queue; custom order; IOU repay **before** sweep; confirm card | No silent auto-sweep |
| Method | Engines + UB / raid / repay fixtures before chrome | No empty War Chest shell without engine |
| Funding spoken-for | Keep Phase 4 tranche-as-expense; Fund `iousC` is Phase 5 spoken-for | Don’t rewrite PruLife into fund earmarks in Slice B |

### Explicit non-changes (Phase 5 skills)

Phase order; personal-scope funds only; Love Tab floor-0; centavos; light mode. Empire/YTD/Balance Day = Phase 6; chat/backup = Phase 7.

---

## Phase 5 Slice A — Loans + Baggage + Checklist tick (2026-08-30)

Skills: Operate, Humanizer, write-swift TDD. Spec §4.11.

| Piece | Behavior |
|---|---|
| Engine | `Loan.derivedBalanceC`; `afterPayment` → paidMonths/balance/status; due on cutoff-matching cycle |
| More | **Baggage We're Carrying** — active + archive; journal |
| Checklist | `loan_payment` tasks; Count it posts Loan Payment + bumps loan |
| Seed | UB Personal 24/60 → ₱628,916.76 |
| Count it UX | Loan Paid from starts **Choose** (no prefill); sheet `countIt ?? item` keeps pick; toggle armed while sheet open |

**Next:** Slice B (funds / raids / War Chest).

---

## Phase 5 Slice B — Funds + War Chest + raids (2026-08-31)

Skills: Operate, Humanizer, write-swift TDD. Spec §4.10. Phase locks reused (no separate micro-pass).

| Piece | Behavior |
|---|---|
| Engine | Raid order loan_payoff → sinking → emergency; IOU absorb / add_to_due; repay oldest-first; `effectiveBalanceC` = cash left (`balanceC`). add-to-due UI hidden; engine path kept |
| More | **The War Chest** — fund cards, owed summary, Borrow / Repay sheets |
| Forecast | Over → “Borrow from a fund” opens War Chest raid (suggested shortfall) |
| Ledger | `fund_move` home→dest; MVP absorb only (IOU on fund); add-to-due UI hidden |
| Seed | Loan payoff · Sinking · Emergency (Fern / BPI Debit) |

**Next:** Slice C (snowball — repay IOUs before sweep).

---

## War Chest Add / Borrow polish (2026-08-31)

Skills: Operate, Humanizer, Emil. Spec §4.10 transfer home → spend pocket.

| Piece | Lock | Push back |
|---|---|---|
| Add placement | List footer **Start a fund** (no leading `+` next to Back); trailing **Borrow** only | — |
| Add fund | Name, purpose, home (Fern **asset** pocket), opening → Fund Move + `balanceC` | No hand-edit balance; no CC/loan as home |
| Owner | Payer (`fern`) only | No contributor War Chest in MVP (§7.7) |
| Top-up | Amount + from account; Fund Move into home; bump `balanceC` | — |
| Card | Show home account label under name | — |
| Borrow | Destination = Fern cash/bank/e-wallet/digital; two-leg Fund Move home→dest; free-text note (default Cover bills) | No Shared/CC dest; Phase 6 owns account balances |
| When it happened | Compact DatePicker (like Add) on Start a fund, Top-up, Borrow; sheets `.large` | Wheel temporary; Repay undated |
| Opening delete | Receipts opening `fund_move` → confirm removes **fund + row** | No ledger-only (orphans In the bank) |
| Repay ledger | Still fund-record only | Reverse dest→home later |
| Loan → fund | Deferred (Baggage “Park payoff…”) | Not this polish |

**Next:** Phase 5 Slice C (snowball — IOU repay before sweep). Then Phase 6 Empire / Balance Day.

---

## Phase 5 Slice C — Snowball (2026-08-31)

Skills: Operate, Humanizer, Emil, write-swift TDD. Spec §4.10–4.11.

| Piece | Lock | Push back |
|---|---|---|
| Queue home | War Chest **Snowball** section (batch groups; order · batch · strategy) | No third More room; Baggage = register only |
| Baggage | Read-only order/batch/strategy chips | Edit only on War Chest |
| Reorder | Row → sheet (order, batch, strategy); **no drag** | Few loans; custom never auto smallest-first |
| Batches | Lowest batch with actives; then `snowballOrder` | Nil batch = 1; nil order last |
| Strategy | `prepay` (+ nil) = Park another month OK; `park_to_maturity` = accumulate only | No separate 2× schema field |
| Sweep | Confirm card: IOUs oldest-first, remainder → loan-payoff; From + date | No silent auto-sweep; Love Tab credit ≠ surplus |
| Forecast | Breathing room → “Park leftover…” opens Sweep with suggested amount | Mirrors over → Borrow |
| Ready to pay | Chip when loan-payoff ≥ next monthly → Checklist / Count it | **Not** Statement day (CC realization) |
| Park From | Confirm sheet: locked `monthlyC`, **From** picker (default fund home), date; Confirm | No silent first Cash pocket; From = home → one Fund Move |
| Sweep From default | Prefill loan-payoff **home** (not first asset) | Align with Top-up / Park |
| Target bar | Cash progress + terra owed sliver | Slice B polish gap |
| Engine | `Snowball` + tests before chrome | Phase 5 accept: repay before park |
| Seed | UB #1 + BPI CC remnant #2 batch 1 | Queue demo |
| Accounting gate | Before any new money path: pockets / envelope / legs / report followability | Push back on unsigned dual-leg or dual truth; see `.cursor/rules/accounting-map.mdc` |

### Queue place clarity polish (2026-08-31)

Skills: Operate, Humanizer, Emil, clarify.

| Piece | Lock | Push back |
|---|---|---|
| Sheet title | **Edit payoff order** | Drop jargon “Queue place” |
| Order / Batch | Separate sections + footers (custom not smallest-first; batch gating) | No twin bare unlabeled numbers |
| Strategy footer | Consequence line for Prepay vs Park to maturity | — |
| List meta | `Pay next · #n · Batch · strategy · monthly` | Teach custom order |
| Ready to pay | “Loan payoff covers…” / Bills → Checklist → Count it | No “from” (not From pocket) |
| Engine / seed order | Unchanged | Spec custom order |
| Strategy display | **Stash extras** / **On schedule only** via `DisplayLabels.loanStrategy` | Engine keeps `prepay` / `park_to_maturity`; “Park another month” action name stays |
| Batch chrome | Hide Batch on list/edit while every active loan is wave 1; **Pay in a later wave…** reveals field | Engine batches unchanged |

### Explicit non-changes (Slice C)

Empire / Balance Day; household funds; add-to-due UI; drag-reorder; Statement-day loan payout; funding-tranche rewrite; signed ± Fund Move legs (known mess — fix with Balance Day / transfer model, don’t add more unsigned dual-legs).

**Phase 5 complete** (A+B+C). **Next:** Phase 6 Snapshots & Empire.

---

## Phase 6 skills critique (2026-08-31, pre-build)

Skills: Impeccable Operate, Humanizer, Emil / apple-design, UI UX Pro Max (mobile Operate), write-swift TDD, accounting-map. Spec §4.6 + §6 Phase 6 accept. **Docs lock — Slice A may start after fixtures + explicit implement ask.**

Phase 6 owns **pocket balances as truth**. Envelope `Fund.balanceC` stays the War Chest book.

| Surface | Recommendation | Why / Push back |
|---|---|---|
| Method | Fixtures + pure `Snapshot` / metrics engine **before** Empire chrome | Accept is numeric |
| IA | More → **Our Little Empire** + **Our Year So Far** first-class (not Fine Print). **Where the Money Sleeps** in Slice C | Spec More grid; don’t invent a third NW room |
| Balance Day | Per person · per cycle anchor; non-archived accounts; tiers **derived** (confirm only) / **prefilled** (edit) / **stale** (skip). Confirm → snapshot + seven metrics | One job — check-in |
| Pocket truth | Snapshot lines = store of record; last-confirmed on account for next prefill | Stop treating envelope-only as NW |
| Spoken-for | Fund envelopes (+ funding reserves) on home pocket — exclude from feels-spendable; **not** a second asset on top of pocket | Accounting-map: no BPI Debit + loan-payoff double-count |
| Seven metrics | assets / liabilities / netWorth / deltas vs prior / **savingsAssets as pesos** | Spec; negative NW unbothered |
| Household | Empire Seg Fern / Stark / Household; Household **nets** Love Tab + fund IOUs to zero (**engine in A**) | Accept; not reverse Love Tab |
| Charts | Swift Charts; negative-friendly axes; ease-out; Reduce Motion = static | Stack + vibe — **Slice B** |
| YTD | Person Seg + split vs just-mine; income/expense bars; category donut; Needs-vs-Wants | Spec — **Slice C** |
| Interest drift | Unexplained positive fund-home drift → confirm “Book as interest?” — **never silent** | Accounting-map — **Slice C** |
| Fund Moves | Balance Day reconciles pockets; **do not** rewrite unsigned two-leg history in A | Known mess; don’t naive-sum Fund Move in charts |
| Copy | Empire / Year So Far cheese titles; Balance Day plain (“Check the balances”); stale = “Skipped” | Humanizer; cheese quarantine on amounts |

### Slice shape

| Slice | Scope | Accept focus |
|---|---|---|
| **A** | Snapshot engine + Balance Day + seven metrics (+ household netting in engine) + golden fixtures; More → Empire **metrics cards** + Balance Day CTA (**no** charts) | Portfolio-Fern 08/20; NW −₱151,537.98 |
| **B** | Empire NW line + A/L area; household Seg chrome | Household nets tab + IOUs to zero in UI |
| **C** | Our Year So Far; interest-drift confirm; Where the Money Sleeps | Follow-the-money charts; drift never silent |

### Explicit non-changes (Phase 6 skills)

Phase 7 chat / backup; Phase 8 sync; household-scoped funds; raid add-to-due UI; swappable payer/contributor (§7.9); auto-sorting snowball; Statement-day loan payout; silent rewrite of historical same-sign Fund Moves; **inventing** Portfolio-Fern numbers.

---

## Phase 6 Slice A — Balance Day + Snapshot engine (locks) (2026-08-31)

Skills: Operate, Humanizer, write-swift TDD, accounting-map. Spec §4.6. Phase locks above reused.

| Piece | Lock | Push back |
|---|---|---|
| Engine | Pure Snapshot metrics from lines + prior deltas; household lens nets Love Tab + fund IOUs | UI never recomputes NW |
| Persistence | Snapshot lines + metrics; last-confirmed on account for next prefill | No envelope pesos as Empire assets |
| Tiers | derived = confirm only; prefilled = investments overwrite; skip → stale | Loan balances stay derived (no hand-type) |
| Spoken-for | Sum fund `balanceC` (+ funding reserves) on home — feels-spendable exclusion only | Don’t add on top of pocket |
| More | **Our Little Empire** — latest seven metrics cards + **Balance Day** CTA | Charts / YTD / Money Sleeps = B/C |
| Balance Day copy | “Check the balances”; skipped = “Skipped” | — |
| Fund Moves | Leave unsigned dual-leg history alone | No rewrite in A |
| Interest drift | Parked to C | No silent interest booking |
| Fixtures | Portfolio-Fern 08/20 + NW −₱151,537.98 **required** before accept / claiming Slice A done | Do not invent from prototype `pantomina-app.jsx` mocks |

**Next:** Obtain Portfolio-Fern golden column → implement Slice A (when asked). Then B (Empire charts) → C (YTD / drift / Money Sleeps).

---

## Portfolio-Fern 08/20 golden (2026-08-31)

Skills: Operate, accounting-map, write-swift. Spec §6 Phase 6 accept.

| Piece | Lock | Push back |
|---|---|---|
| Metrics | `PortfolioFern0820.metrics` — Fern personal 08/20 seven fields; NW −₱151,537.98 | Prototype JSX 8/20 discarded |
| Line vs totals | Sheet asset/liab rows do not sum to SS3 totals | No bridging formula; manual mess |
| Negative NW | Valid starting state; UI unbothered; recovery via tools not lectures | No shame chrome on Empire |
| Savings | Sheet “Savings Rate” pesos → `savingsAssetsC` | Not a percentage |
| Stark | Separate fixture when column arrives | — |

**Next:** Implement Phase 6 Slice A (Snapshot engine + Balance Day) when asked. Then B → C.

---

## Phase 6 Slice A — shipped (2026-08-31)

Skills: Operate, Humanizer, write-swift TDD, accounting-map. Spec §4.6.

| Piece | Behavior |
|---|---|
| Engine | `Snapshot.metrics` — personal/household lens; stale skip; internal debts net on household; negative NW OK |
| Golden | `PortfolioFern0820` Spec accept constants (no line-sum bridge) |
| Persist | `SnapshotRecord` + `AccountRecord.lastConfirmedBalanceC` |
| More | **Our Little Empire** — seven metric cards, person + lens, Balance Day CTA, Preprod demo load |
| Balance Day | “Check the balances” — confirm / skip / prefill; loans derived |
| Non-changes | Charts, YTD, Money Sleeps, interest drift |

**Next:** Slice B (Empire charts) → C (YTD / drift / Money Sleeps).

---

## Empire scope Seg polish (2026-08-31)

Skills: Operate, Humanizer. Fixes nested Personal/Household under Fern/Stark.

| Piece | Lock | Push back |
|---|---|---|
| Empire Seg | **One** peer Seg: Fern · Stark · Household | Not Personal/Household under a person |
| Household | Shared netting view; needs both check-ins with lines | Not “Fern’s household” |
| Balance Day | Whose person on sheet / personal tabs only | No Balance Day from Household tab |
| Demo | Load Fern 08/20 only when Fern has no snapshots; prefer lined check-in over metrics-only for display | Don’t use empty demo as Balance Day prior |

**Next:** Slice B (Empire charts) → C (YTD / drift / Money Sleeps).

---

## Empire dashboard reshape (2026-08-31)

Skills: Operate, Humanizer, accounting-map, write-swift TDD. Spec §4.6 kept; corrects Slice A hand-type-everything.

| Piece | Lock | Push back |
|---|---|---|
| Empire | Read-only dashboard — live metrics + pocket list | Not a balance form |
| PocketBalance | Ledger-known from legs; loan derived; externals lastConfirmed; spoken-for display-only | Don’t naive-sum Fund Move as income |
| Balance Day | Thin — `investment` / `savingsAsset` / `govMandated` only; empty placeholder (not `0.00`) | Omit derived rows |
| Shared | Fern confirms Shared once; Stark = personal only | No double-confirm / double-count |
| Mini-report | Tap pocket → sheet (running balance, recent legs, spoken-for); no edit | Full browser = Money Sleeps (C) |
| Demo | Portfolio-Fern metrics-only still loadable; live lines preferred when present | |

**Next:** Slice B (Empire charts) → C (YTD / drift / Money Sleeps).

---

## Empire cycle as-of (2026-08-31)

Skills: Operate, Humanizer, accounting-map. Spec §4.6 per-cycle check-in.

| Piece | Lock | Push back |
|---|---|---|
| Control | Bills-style **Cycle** Menu under Fern·Stark·Household | Not free from–to; not “statement date” on Empire |
| Balance | **As-of** selected cycle end (`realizedDate ?? purchaseDate` ≤ end) | In-window-only sum would wipe pocket NW |
| Mini-report | Opening + legs in `(prevAnchor, selected]` | Full history stays on Receipts |
| Missing snapshot | Live PocketBalance as-of | Don’t require check-in to see ledger pockets |
| Balance Day | Stamps Empire’s selected `cycleISO` | Today-only stamp wrong when browsing prior cycle |

**Next:** Slice B (Empire charts) → C (YTD / drift / Money Sleeps).

---

## Phase 6 Slice B — Empire charts (2026-09-01)

Skills: Operate, Humanizer, Emil, write-swift TDD. Spec More Empire charts.

| Piece | Lock | Push back |
|---|---|---|
| Charts | NW `LineMark` + assets/liabilities area (sage/terra); stacked portrait | No spreadsheet dual-axis Δ; no per-point labels; no drop shadows |
| Series | `EmpireCharts` from snapshots (+ live tip if cycle missing); household needs both lined | No invented May’25–Aug’26 fixture timeline |
| Interaction | Chart X selection → one caption; Reduce Motion = static | — |
| Savings line | Not in B (`savingsAssets` stays a metric card) | Park denser savings chart |
| Non-changes | YTD / drift / Money Sleeps = C | — |

### Empire sticky flair (same day)

Skills: Operate, Humanizer, Emil, Spec §1 cheese quarantine. Charts felt buried; no new psychology skills.

| Piece | Lock | Push back |
|---|---|---|
| Above fold | NW amount + compact sparkline (+ blush wash when Δ > 0) | Don’t put full A/L chart above fold |
| Metrics | Assets / liabilities compact; changes & savings in DisclosureGroup | Don’t restore seven stacked metric cards |
| Micro-moment | Rose heart pulse once on positive NW Δ | Never on amounts, axes, or negative NW |
| Motion | Ease-out horizontal reveal on appear / series change; Reduce Motion = full reveal | No bounce loops; no fake progress |
| Copy | Empty: “Confirm a cycle’s balances—the empire line starts here.” Quiet empty: “Rare quiet moment.” | No lecture, no shame chrome |

### Empire hybrid hero (same day — supersedes sparkline-beside-NW)

Skills: Operate, Humanizer, Emil; energy + hedging refs for **composition only**.

| Piece | Lock | Push back |
|---|---|---|
| Above fold | NW amount + **full-width** NW line/area (~168pt); blush when cycle Δ > 0 | No dark canvas, orange accents, glow, or 4-KPI strip |
| Tooltip | Chart X selection → card: date, NW, step Δ vs prior point | No dual market/hedged lines; no forecast dashed tail |
| Below fold | Assets & liabilities chart only (NW not duplicated); pockets unchanged | No per-row sparklines |
| Cycle | Keep Bills-style Cycle Menu | No Day/Week/Month chips (series is cycle anchors) |
| Motion / cheese | Ease-out reveal; Reduce Motion static; rose heart on gain; cheese off amounts | — |

**Next:** Slice C (YTD / interest-drift / Where the Money Sleeps).

---

## Phase 6 Slice C — skills + inspiration (2026-09-01)

Skills: Operate, Humanizer, Emil / apple-design, accounting-map, write-swift TDD. Spec More: Our Year So Far, interest drift, Where the Money Sleeps.

**Ship order:** YTD first → interest-drift confirm → Money Sleeps. Gate: Slice B Empire charts merged (#9).

### Inspiration (composition only)

Modern soft finance dashboards (calm cards, income/expense bars, category donut) and prior energy/hedging refs inform **layout**, not skin.

| Steal | Push back |
|---|---|
| Soft card stack; one year control; income vs expense bars; category donut; quiet Needs/Wants totals | Dark/neon/purple fintech; Inter-only AI dashboards; Sankey/FIRE |
| Money Sleeps as scoped account map with spoken-for flags | Second NW room duplicating Empire |
| Drift as confirm sheet (“Book as interest?”) | Silent auto-book; Day/Week/Month grain |

### Product locks

| Piece | Lock | Push back |
|---|---|---|
| YTD | More → Our Year So Far; Fern/Stark Seg; split vs just-mine; monthly bars; expense donut; Needs/Wants from `needWant` | Naive Fund Move dual-leg sums; purchaseDate grouping; projected in totals |
| Accounting | `realizedDate` year window; jar via `jar.kind`; exclude contribution/receivable/fund_move | Envelope pesos as YTD income |
| Drift | Unexplained **positive** fund-home pocket drift → confirm book interest — never silent | Auto-post without confirm |
| Money Sleeps | More link; accounts by scope + spoken-for; edit on Receipts | Seven Empire metrics / NW charts |
| Cheese | Pet title only; empty teach copy; amounts plain | Shame chrome on Needs/Wants |

### Explicit non-changes

Fund Move signed-leg rewrite; dark mode; inventing May–Aug fixture timelines for YTD.

**Next:** Implement YTD engine + UI; then drift; then Money Sleeps.

### Shipped same day (YTD cut)

| Piece | Status |
|---|---|
| `YearSoFar` + Our Year So Far UI | Shipped |
| `InterestDrift` + Balance Day sheet | Shipped |
| Where the Money Sleeps | Shipped |

### Follow-up (Seg + history + donut palette) — 2026-09-01

Skills: Operate / Humanizer / Emil; Spec cheese quarantine.

| Lock | Choice | Reject |
|---|---|---|
| YTD Seg | Fern · Stark · Household (Empire peer); Split\|Just mine only on personal | Person-only Seg; Household + Just mine |
| Household YTD | Full `amountC` once per leg | Fern-split + Stark-split |
| History | Year-window Cycle Menu + chart series; `Cycle.anchors(inYear:)` / `recentAnchors` | Unbounded flat Cycle lists |
| Where it Went | Rank palette tokens + center Spend; top 5 + Other | Charts auto hues; purple/hatch refs |

### Quiet ledger 1c on YTD (2026-09-01)

| Lock | Choice |
|---|---|
| Layout | Flat hairlines; year trailing Menu; underline peer tabs; lens mini-toggle on hero |
| Amounts | Spent / lists / Needs = **ink**; **Earned** = `#2F6B52` only |
| Chart fills | Income bar = quietAccent; expense bar = clay `#C98A6B` (not amount chroma) |
| Insight | Trailing 3‑mo expense average RuleMark + spike caption when ≥1.5× |
| Donut | Side-by-side list; center = top category % |
| Keep | Fraunces “Our Year So Far”; Needs & wants |

### Quiet ledger polish (2026-09-01)

| Item | Done |
|---|---|
| Million-scale hero | Digit-based font size + `minimumScaleFactor` |
| Donut | `innerRadius` 0.78 (thinner ring) |
| Needs · Wants · Savings | Same row; savings = `savings`/`sinking` flows |
| Lens | Charts/totals keyed to Split / Just mine / scope |
| Usual line | Prior up-to-3 months only; always caption vs latest |
| Paper | `#FAF8F5` tab bar + nav + table/collection appearance |

**Phase 6 complete** (A+B+C + Quiet ledger YTD). **Next:** Phase 7 when asked.