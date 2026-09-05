# Pantomina — Design & Build Specification

**Status:** approved for build · v2.4 (SwiftUI) · 2026-08-29
**Name:** **Pantomina** — after the Bicolano "Dance of Love." Brand direction: wordmark in Fraunces ("Pantomina", capital P only); logo mark explores **two doves** (sage + terracotta), not a heart — the heart stays a UI accent, the dove is the identity; dance/courtship copy allowed sparingly ("in step," "our little dance") within the §1 cheese quarantine. Tagline: "two of us, one ledger."
**Audience for this doc:** Cursor AI (implementation agent) + the two humans it serves.
**Ship target:** **iOS App Store** — iPhone-first. Built and archived in **Xcode**, beta via **TestFlight**, release via **App Store Connect**. Not a PWA and not a browser-only app.

> **How to use with Cursor:** this file is the product spec (`APP_SPEC.md`; move to `docs/SPEC.md` at Phase 0 if the tree wants it there). Read `docs/DECISIONS.md` before any task — **Baseline** is locked; **For later** is parked and must not be implemented. Add the rule block from §12 to `.cursor/rules`. Implement one phase per session (§6), in order. Every phase ends with its acceptance checks passing before the next begins. When this spec, DECISIONS, and an ad-hoc instruction conflict, ask; do not silently pick one. Design skills (Taste, Impeccable, Emil Kowalski, UI UX Pro Max) and Superpowers inform UI/UX and method; **this spec + DECISIONS win** if a skill conflicts.

---

## 0. What this is

A shared-finance app for **exactly two people** — a **payer** (fronts the household bills) and a **contributor** (chips in what they can each cycle) — replacing a sophisticated Numbers spreadsheet system. It is a two-person ledger with per-item splits, a bi-weekly settlement engine, credit-card realization accounting, envelope funds, a debt snowball, and bi-weekly net-worth snapshots. Names are chosen per couple at onboarding (§3); this doc uses **Fern** (payer) and **Stark** (contributor) only in fixtures and acceptance tests, where they reflect the real data the engines are validated against.

**The vibe is "knowingly cheesy":** romantic, self-aware, winking — never at the expense of the numbers. Finance without shame; the household net worth is currently negative and climbing, and the app celebrates the climb.

### The one heartbeat

Everything in the system runs on a **bi-weekly cycle anchored to the 15th and 30th** of each month (the "30th" means the last cycle of the month; February's is the 28th/29th). Realization dates, settlement dues, the payment checklist, funding tranches, snapshots, and forecasts all snap to this grid. `Cycle` is a first-class object; nothing invents its own calendar.

---

## 1. Vibe contract (design law)

Cheese lives **only** in: screen titles, empty/success/nudge copy, one blush accent, and at most one micro-moment per screen. It **never** touches amounts, chart labels, errors, or destructive actions.

| Layer | Cheese allowed | Rule |
|---|---|---|
| Screen titles | yes | Fraunces italic pet-title over a plain uppercase system label |
| Empty/success/nudge copy | yes | e.g. "Nothing here yet. Rare quiet moment." No exclamation marks. |
| Accent | limited | blush `#F6DCE1` tint for shared/"Both" states; rose `#B8405E` for hearts and love-note text only — never on data |
| Motion | one moment/screen | heart pulse on net-worth gain; spring on sheet open; no loops, no confetti |
| Data, chart labels, amounts, errors | **never** | "Couldn't save. Try again." |

**Pet-name glossary** (title → system label):
Receipts → Ledger · Cookie Jar → Petty cash · Our Year So Far → Year to date · Whose Turn Is It → Bills due · The Checklist → Payments · The Love Tab → Partner receivable · Baggage We're Carrying → Loans · Our Little Empire → Net worth · Accounts → Pockets and categories · The War Chest → Funds · Things We Keep Doing → Recurring · The Fine Print → Settings.

**Field glossary** (engine → UI): `purchaseDate` → **When it happened** (covers spend, salary, transfer — never “Purchase date” in the UI). Schema property name stays `purchaseDate` until a later rename.

Negative net worth is displayed matter-of-factly; trend copy celebrates direction, never winces at sign.

**Copy rules (apply to every user-facing string):** never use gendered pronouns for the two people — always their names via `person.name` (names are user-editable, so any he/she is both an assumption and a rename bug). Never leak engine vocabulary into the UI: "realize/realized," "projection/actuals," "pull/raid," "record/row," "upsert" are spec words — the UI says "counts," "spoken for," "becomes real," "cover it from a fund," "updates everywhere." Buttons name what happens ("tap a row to edit," not "to act"); an unwired action is disabled and labeled honestly, never a silent dead-end.

## 2. Design system (decided)

Derived from the design-skill audit; these are now decisions, not suggestions.

- **Style:** Soft UI Evolution on an editorial warm-paper ground. Feels like a household object, not fintech.
- **Color:** ground `#FAF8F5`, card `#FDFDFC`, ink `#1D212B`, muted `#6A7181`, hairline `#E9E7E2` (warm grays only). **Fern = sage `#498D6D` (deep `#3B7157`) · Stark = terracotta `#EF8F6C` (deep `#D9764F`)** — stable everywhere, never inverted; income = sage, expense = terracotta. Blush `#F6DCE1` + rose `#B8405E` per §1. Shadows tinted warm (`hsl(30 20% 20% / .06)`), never black. Light mode only.
- **Type:** Fraunces (display; italic for pet-titles, SOFT/opsz axes) + DM Sans (UI/body). Amounts always `font-variant-numeric: tabular-nums slashed-zero`, right-aligned in tables. 12px uppercase tracked eyebrows. Sentence case everywhere.
- **Icons:** Phosphor Regular (1.5px stroke), single weight. Not Lucide.
- **Motion:** ease-out `cubic-bezier(.23,1,.32,1)` for feedback; drawer `cubic-bezier(.32,.72,0,1)` for sheets; springs (duration .5, bounce .2) for the Add sheet and heart pulse. Never `transition: all`, never ease-in. `prefers-reduced-motion` honored globally.
- **Layout:** mobile-first **iPhone** (App Store), 44px touch targets, bottom nav of 5, safe-area padding, radius 12–16, soft multi-layer shadows. **No horizontal scrolling anywhere;** long labels wrap to two lines max (flex containers need `min-width: 0`); amounts never truncate or get pushed off-screen; vertical scrollbars hidden visually, scrolling preserved. iPad / landscape is For later (`docs/DECISIONS.md`).
- **Numbers:** ₱ with grouped thousands, 2 decimals in ledgers, 0 in dashboards. Realistic figures in all mocks/fixtures (₱12,813.34, not ₱13,000).
- **Currency:** PHP only, locked.

## 3. Core concepts & data model

TypeScript types below are the conceptual model; production code is **Swift** (see §6). All money in **centavos as integers** (`amountC` / `Int`); render via a single `formatPeso` util. All dates ISO `YYYY-MM-DD`.

**Input bounds** (enforced by pure engine helpers; UI clamps or rejects — never invents rules):

| Field | Bound |
|---|---|
| Display name (`Person.name`) | max **40** Unicode grapheme clusters; trim; non-empty where required |
| Pet name | max **24**; empty allowed (greetings fall back to display name) |
| Note (ledger entry) | max **200** |
| Money amount (Add amount, custom split legs, any user-entered peso) | **₱1 … ₱100,000,000** inclusive → **1 … 10_000_000_000** centavos |
| Snowball order / batch (`snowballOrder`, `snowballBatch`) | integer **1 … 99**; empty order → unordered (`nil`); UI rejects out-of-range |
| Fund name / Keep Doing title | same as display name (≤40); not person ids |

```ts
type PersonId = 'fern' | 'stark';                       // system ids; display names + pet names in Settings
type Scope = 'household' | 'fern' | 'stark' | 'business';
type FlowType = 'income' | 'expense' | 'transfer' | 'savings' | 'sinking';
type NeedWant = 'need' | 'want' | null;               // null for income/transfers

interface Person {
  id: PersonId;            // 'fern' | 'stark' — STABLE internal id, never shown, never renamed
  name: string;            // display name, editable ('Fern' → 'Marco')
  petName: string | null;  // greetings + nudges only
  role: 'payer' | 'contributor';   // exactly one of each; not swappable in MVP (see §7.9)
  color: 'sage' | 'terra'; // payer = sage, contributor = terra (fixed mapping)
}

// PRODUCTIZATION LAW: no display string is ever stored with a person's name baked in.
// Accounts store { baseName, scope }; the suffixed label ('BDO JCB CC · Marco') is COMPUTED
// at render from the current Person.name. Renaming a person updates every suffix, header,
// chip, and greeting for free, touching zero stored rows. Same for categories, splits, YTD
// lenses, loan owners. If you ever need find-and-replace to rename someone, the model is wrong.

interface Cycle {
  id: string;              // '2025-08-15'
  start: string; end: string;
  anchor: string; index: number; }       // helpers: cycleFor(date), nextStatementCycle(date, account)

interface Account {
  id: string; baseName: string;          // 'BDO JCB CC' — stored WITHOUT person suffix
  // display label is computed: scope==='household' ? baseName : `${baseName} · ${person.name}`
  owner: PersonId | 'household';
  scope: Scope;                          // decides split-table routing (§4.2) + allocation default (§4.4)
  kind: 'cash' | 'ewallet' | 'bank' | 'digital_bank' | 'credit_card'
      | 'savings_asset' | 'investment' | 'gov_mandated' | 'receivable' | 'loan';
  settlement: 'instant' | 'statement';   // instant → anchor realization; statement → pending + confirm (§4.3)
  statementCutoff?: 15 | 30;             // for credit cards
  archived: boolean;
}

interface Category {
  id: string; group: string; item: string;   // 'Groceries' | 'Household'
  flow: FlowType; needWant: NeedWant;
  fixedVariable: 'fixed' | 'variable' | null;
  system: boolean;                       // engine-generated only; hidden from pickers (§4.7)
}

interface Transaction {
  id: string;
  purchaseDate: string;                  // event date (UI: "When it happened"); engine id unchanged
  realizedDate: string | null;           // set when realized; reporting groups by this
  realizedStatus: 'realized' | 'pending' | 'projected';
  proposedRealizedDate: string | null;   // auto-proposed anchor for pending/projected
  amountC: number;
  accountId: string; categoryId: string;
  paidBy: PersonId;
  allocation: { fern: number; stark: number };  // centavos; sums to amountC; §4.2 + §4.4 rules
  note: string | null; merchant: string | null;
  recurringRuleId: string | null;
  settlementRole: 'contribution' | 'receivable' | 'fund_move' | 'loan_payment' | null;
  linkedId: string | null;               // loanId | fundId | settlementId | tranche id
  jar?: { sourceId: string | null;       // who paid in / who took out (unit or person)
    kind: 'income' | 'spend' | 'borrow';
    returned: boolean | null };          // borrows only: repaid yet? (the Return Y/N column)
}

interface JarSource {                    // §4.13 — boarder units + people who pay into petty cash
  id: string; label: string;             // '404', '406', '408', '305', or a person
  kind: 'unit' | 'person';
  expected?: { categoryId: string; amountC: number; cadence: 'monthly' | 'biweekly' }[]; // e.g. internet ₱700/mo
}

interface RecurringRule {
  id: string; template: Omit<Transaction, 'id'|'purchaseDate'|'realizedDate'|'realizedStatus'|'proposedRealizedDate'>;
  cadence: 'biweekly' | 'monthly';
  anchorDay: 15 | 30 | 'both';
  amountBehavior: 'exact' | 'estimate';  // estimate → project last-cycle or 3-cycle average (Meralco)
  startCycle: string; endCycle: string | null; paused: boolean;
}

interface Settlement {                    // one per cycle (§4.1)
  cycleId: string;
  dueC: number;                          // Σ Stark's allocations realized in this cycle on household-scoped spend
  contributedC: number;                  // Σ contribution transactions in cycle
  creditAppliedC: number;                // carried surplus applied
  remainingC: number;                    // max(due − contributed − creditApplied, 0)
  surplusC: number;                      // max(contributed + creditApplied − due, 0) → next cycle's credit
  status: 'open' | 'settled' | 'partial' | 'overpaid';
}
interface LoveTab { balanceC: number; creditC: number;   // floor 0, never flips sign
  history: { cycleId: string; deltaC: number; balanceC: number }[]; }

interface ChecklistTask {                 // §4.8
  id: string; cycleId: string; title: string;
  sourceAccountId: string; amountC: number; amountBehavior: 'exact' | 'estimate';
  kind: 'bill' | 'transfer' | 'cc_statement' | 'fund_tranche' | 'loan_payment';
  paymentsRequired: number; paymentsDone: number;        // '1/2' pattern
  linkedId: string | null; done: boolean;
}

interface FundingPlan {                   // §4.9 — split-funding one bill across paydays
  id: string; billRecurringRuleId: string;
  tranches: { cycleId: string; amountC: number; reserved: boolean }[];
  payoutCycleId: string; reserveC: number;               // earmarked, shown "spoken for"
}

interface Fund {                          // §4.10
  id: string; name: string; purpose: 'emergency' | 'sinking' | 'loan_payoff' | 'goal';
  owner: PersonId;                        // personal-only today; scope field allows 'household' later
  homeAccountId: string; targetC: number | null; balanceC: number;
  iousC: number;                          // household owes this fund (raids not yet replenished)
  iouLog: { date: string; amountC: number; reason: string; repaidC: number }[];
}

interface Loan {                          // §4.11
  id: string; lender: string; description: string; purpose: string;
  owner: PersonId;
  principalC: number; totalLoanC: number; // financed cost incl. interest
  termMonths: number; paidMonths: number;
  monthlyC: number; cutoff: 15 | 30; startDate: string; endDate: string;
  apr: number;                            // 0 allowed
  balanceC: number;                       // derived: totalLoan − paidMonths×monthly; confirmed on Balance Day
  snowballOrder: number | null; snowballBatch: number | null;
  strategy: 'prepay' | 'park_to_maturity' | null;        // park = accumulate in fund, pay on schedule
  linkedReceivableAccountId: string | null;              // e.g. RJ repaying Magarao
  journal: { date: string; note: string }[];             // decision log
  status: 'active' | 'done';
}

interface Snapshot {                      // §4.6 — one per anchor per person
  cycleId: string; person: PersonId;
  lines: { accountId: string; balanceC: number; source: 'derived' | 'confirmed' | 'stale' }[];
  metrics: { assetsC: number; liabilitiesC: number; netWorthC: number;
    netWorthDeltaC: number; assetsDeltaC: number; liabilitiesDeltaC: number;
    savingsAssetsC: number };            // a peso amount, NOT a percentage
}
```

## 4. Business rules (the twelve use cases, precisely)

### 4.1 Settlement & the Love Tab
Fern fronts all household bills; Stark contributes what she can, logged as `settlementRole:'contribution'` (Transfer). Per cycle: `due = Σ Stark allocations` on household-scoped transactions **realized in that cycle**; `remaining = max(due − contributed − carriedCredit, 0)`. Remaining posts a `receivable` transaction and increments the **Love Tab** (Fern asset / Stark liability). Overpayment first nets the tab; surplus past zero becomes `credit` for the next cycle. **The tab floors at 0 and never flips direction.** Status chips: settled / partial / overpaid.

### 4.2 Allocation asymmetry & scope routing
Every transaction carries explicit per-person centavo allocations (not %). Routing rule for **household-scoped** instruments: if the **payer (Fern)** pays a shared item → both allocations are recorded as unrealized dues (Fern's tracks Fern's share of household spend; Stark's feeds Stark's cycle due). If the **contributor (Stark)** pays a shared item → only Fern's share is recorded (`allocation.stark = 0`) — Stark's half was realized the moment Stark paid; **no reverse debt is ever created**; Fern's share simply lands in Fern's own split totals for the cycle. **Personal-scoped** instruments (`Cash-Fern`, `BPI CC-Fern`, …) feed that person's individual ledger; **business** scope feeds a business P&L. Reporting views: "my share of us" (split) vs "just me" (individual), per person — filtered entirely by account scope + allocations.

### 4.3 Two-date realization
`purchaseDate` is always the **event date** (swipe, pay, salary, transfer — UI label “When it happened”). **Instant accounts** (cash/debit/e-wallet/digital bank): auto-realize with `realizedDate` = current half-month anchor — event on the 1st–15th → 15th of that month; 16th–EOM → 30th of that month. Deterministic, no confirmation. **Statement accounts** (all CCs): born `pending` with `proposedRealizedDate` = next statement cycle (can be a month+ out); confirmed in the **Statement day flow**: pick card + cycle → tick swipes present on the statement → batch-realize to that anchor; unticked stay pending (the TBD pool). All reporting (YTD, splits, dues, forecasts) groups by realized date; pending totals are always visible as a "TBD drawer," never hidden.

### 4.4 No-split entries
Any entry can be marked *just mine*: 100% allocation to the payer regardless of instrument. Defaults: personal-scoped accounts → just-mine; household accounts → 50/50. Both overridable per entry, including custom peso splits.

### 4.5 Projection & cycle forecast
Fixed items are **never hand-posted ahead**. Future cycles display `projected` transactions generated from recurring rules (ghosted, "projected" chip); at the anchor (or when the real bill lands) each is confirmed into an actual — one tap if exact, edit-then-confirm if `estimate` (electricity projects last cycle or 3-cycle average). Projections never count in actuals. The Bills header shows the **cycle forecast**: expected income + expected contribution vs committed (projected fixed + funding tranches + pending CC charges proposed to land this cycle) vs typical variable → "₱4,210 breathing room" / "over by ₱1,850." Projected shortfalls link to the fund-raid flow (§4.10).

### 4.6 Snapshots (Balance Day)
On each anchor, a check-in per person lists every non-archived account. Three tiers: **derived** (ledger-known: cash flows, loan balances, Love Tab, subscription liabilities from rules) shown for confirmation only; **prefilled** (investments/external: PruLife, Philstocks, GoTrade, CoinsPH…) with last value, overwrite what moved; skipped accounts marked `stale`. Confirm → compute all seven metrics. **`savingsAssets` is a peso amount** (time deposits + sinking + regular savings), not a rate. Net worth may be negative; UI is unbothered. **Household view nets internal debts** (Love Tab, fund IOUs) to zero. Subscriptions are carried as standing liabilities per the owner's model — classification editable per item. Unexplained positive drift on fund home-accounts offers "book as interest income?"

### 4.7 Chart of accounts
Category = clean `Group|Item` **without** person suffixes; person lives in scope/allocations, not names (Travels: 17 → 6 entries; total ≈ 190 → ≈ 85). `needWant` and `fixedVariable` are fields. **System categories** (engine-generated, hidden from pickers): Partner Contribution, Partner Receivable, Fund Move, Loan Payment, Petty Cash. "Unrealized *" categories are deleted — that's `realizedStatus` now. `Loan Reserve|*` → funding plans; duplicate Annulment sinking entries → one Fund. Migration table maps every legacy string → new category + scope + tags; migration surfaces (never silently keeps or fixes) tag oddities: all `Loan|*` as Wants, `Child Support|Birthday` Wants vs `Siblings|Birthday` Needs, `Smart Postpaid` as the only Wants utility. Typos fixed (`Subcription`, `Accomodation`). Life-domain groups (Papa, Magarao, Child Support, Projects…) keep their names exactly.

### 4.8 The Checklist
Task-based payment list per cycle, generated from recurring rules + funding tranches + loan schedules: each task = source account, amount (exact/estimate), kind, and `paymentsDone/paymentsRequired` (the `1/2` pattern). Includes non-expense buttons that must be pushed: CC statement payments (ticking opens Statement day, §4.3), fund tranches, sinking transfers. **Ticking = mark paid + realize the linked ledger entry** (+ loan updates per §4.11). Header: "9 of 15 paid · ₱43,210 still to send." Past-cutoff unticked items get one gentle flag.

### 4.9 Funding plans (split-funding one bill)
A large bill (PruLife, UB Personal Loan) can be funded in N tranches across cycles with a single payout on the due cycle. Tranches appear as reserve-transfer tasks; the payout task consumes the reserve. Status: `funded k/n → paid`. The reserve is a visible earmarked bucket — an asset flagged "spoken for," excluded from feels-spendable. Forecast charges each cycle its tranche, not the payout cycle the full amount. When a single fixed bill exceeds a configurable share of typical cycle inflow, offer split-funding once.

### 4.10 Funds, snowball, raids & IOUs
Funds are first-class envelopes mapped to real home accounts, **personal-scope only today** (owner currently Fern; `household` scope is a future toggle, not a feature now — one quiet "someday: a shared one" line max). **Snowball engine:** loans carry a custom payoff order + batches (not auto smallest-first); cycle-close surplus suggests a sweep to the loan-payoff fund; when the fund covers the target, propose the payout through the CC-statement flow. Supports **2× allocation** (schedule unchanged, extra parked) and **park-to-maturity** (accumulate to avoid pre-termination fees; pay on schedule). **Raids:** when a cycle can't cover bills, pull from funds in configurable raid order (loan-payoff → sinking → emergency default) and record it as two linked writes: a `fund_move` **transfer in the main ledger** (fund home account → bills) and an internal IOU: *"Household bills owe Fern's Emergency Fund ₱6,500 since Jul 15."* Partial repayments settle the oldest IOU first. Attribution is explicit (personal money covering shared obligation); whether it also feeds Stark's due is a per-raid choice, default **absorb**. Funds display real / IOU / effective balance. Surpluses suggest IOU repayment **before** snowball sweeps; show "made whole by ~date at current pace." Visibility without nagging.

### 4.11 Loan register
Fields per §3. Balance is **derived** (`totalLoan − paidMonths × monthly`) and confirmed, never hand-typed; **ticking a loan payment on the Checklist**: realizes the ledger entry, increments `paidMonths`, decrements `balanceC`, feeds the next snapshot — the manual three-step update is dead. Show principal vs total vs cost-of-borrowing delta; progress in months, not just pesos; APR with 0% distinguished (snowball-aware). Purpose strings displayed prominently. Decision journal = dated notes timeline. A loan may link a receivable account (someone repaying it). `Done` loans move to an archive shelf ("Baggage we put down" — the one cheese line allowed here).

### 4.12 AI chat entry
Chat is the front door of Add (form remains as fallback). **Phase 7 Room A:** the composer **is** the sheet; Fix something pushes the Quiet-ledger form prefilled (`docs/phase-7-prd.md`). Free text → parsed draft → **confirmation card** (never auto-saved): amount, category+tags from CoA, account (→ scope), paid-by, allocation per §4.2/4.4, realization status + proposed date per §4.3, settlement routing if it's a contribution. One-tap Save; "Fix something" opens the form prefilled. Ambiguity = exactly one question ("which card — BPI or BPI-Fern?"). Batch: multiple entries in one message → multiple cards. Corrections persist as merchant/shorthand mappings ("meralco" → Utilities|Electricity, MariBank). **Phase 7 Slice A golden utterances** (offline rules parser; event date in tests is `2026-09-05`; “When it counts” from `Realization` / `Cycle`, never a hardcoded calendar line). Starter CoA + pockets. Display names in copy are live; fixtures use Fern / Stark.

| # | Kind | Utterance | Expected draft |
|---|---|---|---|
| 1 | Clean card | `home grocery Robinsons 3000 bpi cc` | ₱3,000.00 · merchant Robinsons · Groceries · Household · BPI CC · Fern · paid by Fern · Just mine · Waiting on statement · counts on Oct 15, 2026 |
| 2 | Ambiguity | `gcash 320` | ₱320.00 · one question “Which GCash, Fern or Stark?” · choices GCash · Fern / GCash · Stark · When it counts `-` · Save off until pick. After Fern: Just mine · Counts on Sep 15, 2026 |
| 3 | Contribution | `stark put in 7500` | ₱7,500.00 · Partner Contribution · House cash box · paid by Stark · `contribution` · allocation 0/0 · Counts on Sep 15, 2026 |

Composer “Things that work” shows the last three successfully saved typed sentences (newest first), padded with these goldens. Empty Fix something by hand and failed-parse hand-fill do not write recents. Artboard stand-ins are not fixtures.

**iOS Shortcuts / App Intents are kept:** a Shortcut or App Intent posts raw text to the same parse pipeline; results land in an unconfirmed-entries inbox swept at day's end. Prototype: call the Anthropic API from the artifact. Production: **an optional bring-your-own Gemini API key** (Settings → AI, §5) stored in the **iOS Keychain** — when present, the client calls Gemini directly with the user's key; when absent, a deterministic local rules fallback (regex amount/account/keyword match) so capture always works offline and key-free.

### 4.13 Petty cash (The Cookie Jar)
The jar is the main ledger filtered to `jar` entries, but with sub-ledger behavior: a **statement-style running balance** (each row shows balance-after, ordered by realized/bill date). Entries carry a `jar.kind`: **income** (a source paying in — boarder unit internet ₱700, laundry ₱500, refunds), **spend** (a dip: pocket money, aircon cleaning), or **borrow** (a dip expected back — "Fern No Cash"). Borrows carry `returned: false` until marked repaid; unreturned borrows are the jar's IOU ledger — the **same internal-IOU engine** as fund raids (§4.10), structurally the same idea as the Love Tab: visible, attributed, gently nudged, never nagged. **Sources are first-class** (`JarSource`): boarder units (404/406/408/305) and people, each optionally carrying expected recurring payments (internet ₱700/month per unit) — letting the jar show a per-cycle "who's paid" strip (404 ✓ · 305 ✓ · 408 —) generated from the same recurring machinery as §4.5; **tapping a unit chip filters the statement to that source** and shows a summary line ("Unit 404 · 2 payments on record · last paid Aug 12 (₱700)"), tap again or "clear ×" to unfilter. Two-date realization applies as everywhere. Jar income counts in YTD income; a borrow counts in no one's expenses until repaid (nets out) or written off (converts to spend).

### 4.14 Backup & restore
Backups are a pair: a **schema-versioned JSON envelope** (full fidelity — every entity, id, status, and link; the only restorable format) plus a **CSV bundle** alongside (spreadsheet-friendly, export-only, explicitly not restorable since it flattens allocations, jar/borrow status, and plan links). Settings offers auto-backup cadence **off / daily / weekly / bi-weekly (on cycle anchors)**. iOS background refresh is not reliable enough to be the only trigger, so cadence = checked on **app open and foreground** and generated when due, plus a manual "Back up now." Keep the last 5 auto-backups; files leave the app via the **iOS share sheet / Files / document picker** (not a browser download). **Restore** (Settings): pick a JSON backup via the document picker → validate schema version + checksum → **preview** (entity counts, date range, person names, app version) → choose **Replace everything** (wipe + load) or **Merge** (upsert by id, newer `updatedAt` wins) → type-to-confirm on Replace. Restoring an older schema runs forward-migrations; restoring a *newer* schema than the app understands is refused with a clear message. Every restore auto-snapshots the current data first, so a bad restore is itself reversible. The Gemini API key is **never** written into a backup.

## 5. Information architecture

Bottom nav: **Home · Receipts · Add(+) · Bills · More**

- **Home** — cycle in the nav subtitle; **Due next** (next cycle’s committed bills from Forecast, up to two cards); Add to the pile; latest 3 receipts. Love Tab / net-this-month / checklist strips are not on Home yet. A last-cycle commendation strip (fewer Wants / more parked vs prior closed cycle) is parked **after Phase 7** (`docs/DECISIONS.md`).
- **Receipts** *(The Receipts)* — ledger grouped by day; filters: person, scope, flow, realized/pending/projected; TBD drawer pinned; unconfirmed-inbox badge (Shortcut captures).
- **Add** *(Add to the pile)* — chat-first (§4.12, Phase 7 Room A artboards): composer is the sheet; confirmation card never auto-saves; Fix something **pushes** the Quiet-ledger form prefilled. Form: amount; **Category picker** (searchable, recents pinned first — bumped on pick, grouped by CoA group, no-match allows typing a new one routed through Accounts); **Payment method picker** (searchable, recents, grouped Shared / payer-personal / contributor-personal, rows show scope chip + "statement" chip on CCs; selecting auto-sets paid-by + allocation default per §4.4 and shows a one-line realization hint per §4.3); allocation **Just mine / 50·50 / Custom** where Custom = two mutually auto-filling peso fields with a live sum check (never one locked field); **Cookie Jar toggle** (sets jar source, and for expenses a Spend/Borrow choice per §4.13). No type picker and no recurring toggle on Add (Keep Doing owns habits).
- **Bills** *(Whose Turn Is It)* — four views: **The split** (settlement panel: due → contributed → remaining, progress, status; fixed/variable per person + stacked chart), **Forecast** (§4.5: cycle selector; verdict card — breathing room / over, with the in − committed − variable math shown; itemized Expected in and Committed lists with reason chips fixed/estimate/card-lands-here/tranche; footer states nothing is booked; "over" links to the fund-raid flow), **The Checklist** (§4.8), **The Love Tab** (balance, area chart, cycle history, credit).
- **First-run onboarding** *(Shall we dance?)* — blank-start flow for a new couple, **three steps:** (1) two names plus a display-only PHP chip (pet names skipped here — optional later in Settings); (2) assign **payer** (fronts the bills) vs **contributor**, with a plain-language explainer since it sets the settlement direction; (3) optional starter payment methods + common categories, skippable. Currency is Philippine peso only (no picker). Writes two `Person` records; seeds nothing person-suffixed. Re-runnable from Settings.
- **More** — grid: Our Year So Far (YTD: person seg + split-vs-individual lens, income/expense bars, category donut, Needs-vs-Wants), Our Little Empire (seven metrics, negative-friendly net-worth line, assets-vs-liabilities area, Balance Day entry), The War Chest (fund cards: "In the bank" + owed-back chip + "whole again at" figure + target bar with a distinct sliver for the owed portion; a top summary card when anything is owed; **Borrow to cover bills** sheet — fund pick in raid order with an emergency-fund caution line, amount validated against the fund, and the per-raid choice "payer absorbs" (default) vs "add to contributor's due"; Repay sheet prefilled with the owed amount, partials allowed; snowball queue), Baggage We're Carrying (loan register + archive), The Cookie Jar (petty cash sub-ledger per §4.13: running balance, sources with "who's paid" strip, borrows with return status), Accounts (pockets by scope with live balances and spoken-for flags; create/edit pockets and user categories on the same screen; no 40pt pocket total), Things We Keep Doing (recurring rules + funding plans), The Fine Print (edit names — updates every computed label live per §3; **pet names optional, collapsed by default** behind an "Add pet names" disclosure — off is the norm since some couples share one nickname, and when empty greetings fall back to real names, never a duplicated pet name; cycle anchors; raid order; roles shown read-only per §7.9; pockets and categories live on Accounts, not here; **AI (advanced), collapsed** — bring-your-own **Gemini API key**, stored in the **iOS Keychain**, never synced, never logged, never included in backups, masked input with show/clear + "test key", empty ⇒ AI entry silently falls back to the deterministic rules parser (§4.12), copy notes the key bills the user's own Google account; **Backups** — auto-backup cadence off/daily/weekly/bi-weekly, "Back up now", restore from JSON with preview + Replace/Merge per §4.14; export CSV).

## 6. Build phases

**Delivery.** Pantomina ships as a native **iOS App Store** app (iPhone-only). Day-to-day development is **Xcode + SwiftUI** on the Simulator/device; shipping is **Xcode → archive → TestFlight → App Store Connect**. Do not scaffold Capacitor, React Native, or a PWA for MVP (`docs/DECISIONS.md`). The React file `pantomina-app.jsx` is a visual reference only.

**Stack:** **Swift + SwiftUI + SwiftData (on-device, local-first) + Swift Charts + Swift Testing/XCTest + PostHog iOS (PII firewall).** Paid App Store download (no IAP). Single-device MVP; sync for two devices is Phase 8 (post-MVP); the schema is designed for it (ids, timestamps, soft deletes).

Every phase: bite-sized tasks, tests first for engine logic, commit per task, phase ends only when acceptance checks pass. **Engines are pure Swift functions/modules with no UI imports** — this is what makes the rules testable and what Cursor should build first in each phase. Engine tests run on the host via Swift Testing/XCTest; Simulator checks are for shell, SwiftData persistence, and plugins.

**Phase 0 — Foundation.** Scaffold the **Xcode** iPhone-only app (iOS 17.6+, bundles `pantomina.heginaholdings.com` + `.preprod`, Preprod + Prod schemes); design tokens (§2) as Swift color/type/spacing/motion; primitives (Card, Eyebrow, PetTitle, Amount, Chip, Seg, PersonDot, Sheet, BottomNav); `formatPeso`, cycle math (`cycleFor`, anchors, Feb edge); safe-area + status bar; Reduce Motion. ✅ *Accept:* cycle math unit tests pass incl. month-end/February; primitives visible on a Preprod debug/home surface; reduced-motion verified; the app launches in the **iOS Simulator** from Xcode.

**Phase 1 — Identity, accounts, CoA, ledger.** Two `Person` records (ids `fern`/`stark`, names/pet/role/color) + first-run onboarding ("Shall we dance?"); the render-time label computation (§3 productization law) so no suffix is ever stored; SwiftData schema; seed real accounts (as `{baseName, scope}`) + migrated CoA (§4.7) with migration table + oddity prompts; Receipts list with filters; manual form Add. ✅ *Accept:* renaming a person in Settings updates every account label, chip, header, and greeting with zero stored-row edits; onboarding a blank couple produces a working empty app; legacy category strings map losslessly; scope filters agree with hand-computed fixtures from the spreadsheet screenshots; killing and relaunching the Simulator app restores the same ledger.

**Phase 2 — Realization engine.** §4.3 pure functions; instant-anchor auto-realize; pending + proposal for CCs; Statement day flow; TBD drawer. ✅ *Accept:* fixture: 07/04 BDO JCB swipe proposes 08/15; 06/28 cash realizes 06/30; reports group by realizedDate; TBD sum matches fixtures.

**Phase 3 — Allocations & settlement.** §4.2 routing + §4.4 defaults; settlement computation per cycle; Love Tab with floor-0 credit carry; Bills "split" + "Love Tab" views. ✅ *Accept:* golden test reproduces the real Aug 15 cycle — due ₱12,813.34, contributed ₱5,000, remaining ₱7,813.34, tab ₱177,697.81; Stark-paid shared item yields stark-allocation 0; overpay fixture nets tab, floors at 0, carries credit.

**Phase 4 — Recurring, projection, checklist, funding plans, petty cash.** Rule engine + projected transactions; confirm-into-actual; cycle forecast; Checklist generation incl. n/m payments; tick = pay + realize; funding plans with reserves (§4.9); Cookie Jar sub-ledger (§4.13): running balance, JarSource registry with expected payments + "who's paid" strip, borrow/return tracking. ✅ *Accept:* projections never appear in actual totals; forecast charges tranches to their own cycles; PruLife `funded 1/2 → 2/2 → paid` walkthrough matches the AUTO BILLS table semantics; jar fixture reproduces the Petty Cash Tracker running balance row-for-row (incl. borrows shown parenthesized) and an unreturned borrow surfaces in the IOU list until marked returned.

**Phase 5 — Loans & funds.** Loan register with derived balances + journal + archive; checklist tick updates paidMonths/balance; funds with home accounts, snowball queue (custom order/batches, 2×, park-to-maturity), raids + IOU ledger + repayment suggestions (§4.10–4.11). ✅ *Accept:* UB Personal fixture: 24/60 paid → balance ₱628,916.76 derived exactly; raid creates IOU with correct attribution; repayment ordering runs before snowball sweep.

**Phase 6 — Snapshots & Empire.** Balance Day flow (derived/prefilled/stale tiers); seven metrics with savingsAssets as pesos; household netting of internal debts; Empire + YTD charts (negative-friendly axes); interest-drift booking. ✅ *Accept:* metrics reproduce the Portfolio-Fern 08/20 column from fixtures; household view nets tab + IOUs to zero; NW −₱151,537.98 renders without special-casing.

**Phase 7 — AI chat entry, backup/restore, polish, TestFlight.** Parse pipeline (API + rules fallback), confirmation cards, one-question ambiguity, batch, shorthand memory, App Intent / Shortcuts → inbox; backup & restore per §4.14 (JSON envelope + CSV bundle, cadence check on open/foreground, iOS document picker, restore preview with Replace/Merge, pre-restore auto-snapshot); Gemini key in Keychain; then full vibe pass (§1–2 audit), a11y (focus, contrast, 44px targets), empty/error states everywhere. App Store readiness: usage-description strings, no debug logging of amounts/PII, privacy nutrition labels drafted. ✅ *Accept:* the three sample utterances in §4.12 produce correct cards offline via rules fallback; **round-trip test: back up → wipe → restore ⇒ byte-identical entity sets and identical derived metrics** (settlement, tab, jar balance, snapshots); a due cadence generates a backup on open; restoring a newer-schema file is refused gracefully; axe/contrast checks pass; every screen has a designed empty state; Xcode can **Archive** an installable build for TestFlight (upload may wait on signing/certs).

**Phase 8 (post-MVP) — Sync.** Supabase, auth for exactly two, row-level security, conflict = last-write-wins + review log. Out of MVP scope; do not let it leak earlier.

## 7. Non-negotiables (Cursor: never change without asking)

1. Exactly two people; no third seat anywhere.
2. Fern = sage, Stark = terracotta; income green, expense terracotta; never inverted.
3. All money integer centavos; all cycle math through the shared helpers; the 15th/30th heartbeat everywhere.
4. Love Tab floors at 0, one direction only; no reverse tab.
5. Projections and pending items never count as actuals.
6. Cheese quarantine (§1): never on data, labels, errors.
7. Funds are personal-scope in MVP.
8. Engine logic = pure, tested functions; UI consumes, never computes rules inline.
9. Person names are display-only and editable; internal ids (`fern`/`stark`) are permanent. No person's name is ever stored inside another value (account labels, categories, splits are all computed). Roles are exactly one payer + one contributor and are **not** swappable in MVP — the settlement engine and Love Tab assume this direction.
10. MVP ships as an **iOS App Store** app (SwiftUI + Xcode + TestFlight). **SwiftData** is the store of record; do not persist the ledger in IndexedDB or Capacitor SQLite.

---

*§12 — `.cursor/rules` block:*

```
You are implementing Pantomina per APP_SPEC.md. Read it and
docs/DECISIONS.md before any task. Baseline decisions are locked;
do not implement For-later items. Work one phase at a time, in order;
do not start a phase before the prior phase's acceptance checks pass.
Engine rules live as pure Swift modules (Swift Testing / XCTest,
test-first / Superpowers TDD); UI never reimplements rules. Money is
integer centavos; dates ISO; all cycle math via the shared Cycle engine.
Person ids are fern (payer, sage) and stark (contributor, terra).
Respect the non-negotiables in SPEC §7 and the vibe contract in §1-2
(Fraunces/DM Sans, sage/terracotta person colors, tabular numerals,
ease-out motion, reduced-motion support, light mode only).
Ship target is the iOS App Store via SwiftUI + Xcode + TestFlight;
do not treat this as a PWA or Capacitor app. For UI/UX, apply the
installed design skills (Taste, Impeccable, Emil Kowalski, UI UX Pro Max,
write-swift, apple-design); spec + DECISIONS win on conflict. Use the
golden fixtures named in each phase's acceptance checks; when the spec
is ambiguous or conflicts with an instruction, ask before coding.
Commit per task with descriptive messages. No new dependencies beyond
the stack in SPEC §6 without asking.
```
