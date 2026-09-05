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
| 2026-08-23 | UI stays **Vite + React 18 + TypeScript + Tailwind + restyled shadcn + Recharts + Phosphor**. Native shell is **Capacitor** (`ios/` Xcode project). Not SwiftUI, not React Native, for MVP. **superseded** → 2026-08-29 SwiftUI row. | Spec UI was DOM; Capacitor was the first ship bet. |
| 2026-08-23 | Persistence is **SQLite on device** via Capacitor. **IndexedDB / Dexie is not the store of record.** **superseded** → 2026-08-29 SwiftData row. | iOS can evict WKWebView web storage. |
| 2026-08-23 | **Local-first, single-device MVP.** Sync is Phase 8 only. | Spec §6 / §8. |
| 2026-08-23 | Optional Gemini API key lives in the **iOS Keychain**. Never in SwiftData / SQLite, JSON backups, logs, or screenshots. | App Store + finance-app hygiene. |
| 2026-08-23 | Capture from **iOS Shortcuts / App Intents** into the unconfirmed-entries inbox (same parse pipeline as in-app chat). Not a public webhook. | Native equivalent of the spec's Shortcut door. |
| 2026-08-23 | Backups use the **iOS share sheet / Files / document picker**. Cadence is checked on **open and foreground**, plus manual "Back up now." Do not depend on background fetch as the only trigger. | iOS background work is opportunistic; a missed backup of a ledger is unacceptable. |
| 2026-08-23 | Engine work is **test-first** (Vitest, Superpowers TDD). UI consumes `src/engine` and does not reimplement rules. **superseded** → 2026-08-29 Swift Testing row. | Spec §6–§7. |
| 2026-08-23 | Installed design/method skills (Taste, Impeccable, Emil Kowalski, UI UX Pro Max, Superpowers) inform UI/UX and process. **`APP_SPEC.md` + this file win** if a skill conflicts (e.g. skill wants Inter/dark mode/confetti; spec forbids them). | Skills are taste and method, not product law. |
| 2026-08-23 | Spec visual direction stays **Soft UI Evolution** on warm paper: Fraunces + DM Sans, sage/terracotta, light mode only, cheese quarantine. Skills may refine craft; they may not replace the system. | Spec §1–§2. |
| 2026-08-23 | For **product UI** (ledger, bills, sheets), prefer **Impeccable, UI UX Pro Max, Emil (`emil-design-eng` / `apple-design` / `animate`), and Taste `high-end-visual-design`**. Taste `design-taste-frontend` is landing-page oriented — use it for marketing/onboarding polish only, not for data tables. Also use **`write-swift`** for Swift code. | Taste v2 excludes dashboards; native stack needs write-swift. |
| 2026-08-29 | UI is **Swift + SwiftUI** (MVVM + `@Observable`). Persistence is **SwiftData** on device. Not Capacitor, not React Native, not a PWA for MVP. Charts via **Swift Charts**. | Human lock after playbook review; iPhone-only native fit. Supersedes Capacitor/React/SQLite-Capacitor. |
| 2026-08-29 | Engine rules are **pure Swift** (value types), test-first with **Swift Testing / XCTest**. UI never reimplements rules. Money is integer **centavos**. | Same product law as before; language follows UI stack. |
| 2026-08-29 | Stable person ids are **`fern`** (payer, sage) and **`stark`** (contributor, terracotta). Display names are editable; ids never shown and never renamed. | Human amendment to skills review; replaces `larr` / `len`. |
| 2026-08-29 | Monetization: **paid App Store download**. No freemium, no IAP, no paywall. | Sell from day one; Apple listing price gates install. |
| 2026-08-29 | **PostHog** for diagnostics (paying users). Hard PII/ledger firewall: never amounts, names, notes, merchants, categories, Gemini text, backups, or Keychain material. | Proactive monitoring without leaking the ledger. |
| 2026-08-29 | Bundle IDs: Prod `pantomina.heginaholdings.com`, Preprod `pantomina.heginaholdings.com.preprod`. Schemes: **Preprod** + **Prod** only (no separate Dev bundle). Min iOS **17.6**. iPhone only (`TARGETED_DEVICE_FAMILY = 1`). | Side-by-side TestFlight; browser prototype is reference only. |
| 2026-08-29 | Skills review findings in `docs/SKILLS_REVIEW.md` are approved (with fern/stark). Phase skip requires a dated Why in this file. | Conscious override pattern from Uswag playbook. |
| 2026-08-29 | **Phase 1** shipped: SwiftData ledger, onboarding, seed CoA/accounts, Receipts filters, Add form, Settings rename → computed labels. | Spec §6 Phase 1 acceptance. |
| 2026-08-29 | **Input bounds:** display name ≤40 graphemes, pet ≤24, note ≤200; money **₱1…₱100,000,000** (1…10_000_000_000 centavos). Engine helpers + UI clamp/reject. | Harden free-text and amount entry; salary/transfers need a sane ceiling. |
| 2026-08-29 | UI date label is **When it happened**; schema/engine field stays `purchaseDate`. | Salary and transfers are not purchases; avoid leaking engine nouns. |
| 2026-08-29 | **Pre–Phase 2 UI polish:** light-mode lock; Fraunces + DM Sans (OFL variable fonts); no horizontal filter scroll; status/scope display maps (`DisplayLabels`); Home Add CTA + recent 3; Bills/More honest stubs; reduce-motion helper; 44pt filter chips. | Spec §1–2 vibe before realization engine. |
| 2026-08-29 | Add sheet has **no Close**; dismiss is interactive pull-down. No keyboard Done — Save resigns focus. | Avoid duplicate exits; reduce dismiss/keyboard frame warnings. |
| 2026-08-29 | **Phase 2** shipped: `Realization` + `Cycle.nextStatementCycle`; Add uses engine; Receipts TBD drawer + group by realized date; Statement day batch-count. Accept fixtures: cash 06/28→06/30; BDO JCB 07/04 proposes 08/15. | Spec §6 Phase 2. |
| 2026-08-29 | After Save, defer toast / dismiss / `@AppStorage` off the current update; Bills + Receipts + Statement day snapshot `@Query` people once per body (no computed getters into Query during refresh). | Avoids AttributeGraph “setting value during update” when SwiftData invalidates tab-stack views (e.g. Log contribution Save). |
| 2026-08-29 | **Statement day:** “Counts on” offers cutoff-matching cycle candidates (not only stored proposals); list shows **all** pending for the card; ticks realize to the chosen cycle. Add still auto-proposes via `nextStatementCycle`. | Matches paper-statement workflow; overlapping billing cycles without changing Phase 2 proposal rule. |
| 2026-08-29 | **Phase 3** shipped: `AllocationRouting` (§4.2), `Settlement` + Love Tab floor-0/credit; `settlementRole`/`linkedId` on transactions; Bills **The split** + **The Love Tab** only (Forecast/Checklist stay Phase 4). Accept fixtures: Aug 15 due ₱12,813.34 / contrib ₱5,000 / remaining ₱7,813.34 / tab ₱177,697.81; Stark-paid shared → stark 0; overpay nets tab. | Spec §6 Phase 3. |
| 2026-08-29 | Bills **The split** shows pending statement Stark-share as **Still in the pile** (not in due); due stays realized-household-only. | Spec §4.3 pending never count as actuals; avoids empty “Settled ₱0” confusion on CC swipes. |
| 2026-08-29 | Bills **The split** adds **Fern’s share of shared spends** (`Settlement.householdShares`) under Stark settle — includes pending statement by `proposedRealizedDate`. Planning/covers only; **not** reverse Love Tab. | Spreadsheet: Stark pays household card → Fern half still planned for statement; settle due unchanged. |
| 2026-08-29 | **Pre–Phase 4 polish:** Bills settle → Fern covers → actions order; humanized captions; account picker `Shared · Statement`; cycle picker always when anchors exist; seed **Income · Side hustle** (backfill on existing installs). | Skills Operate/Humanizer/Emil before Forecast/Checklist. |
| 2026-08-29 | **Phase 4 UX locks (pre-build):** Bills four panes (scrollable Seg); Forecast verdict-first + booked-nothing footer; “over” → Phase 5 raid pointer only; Projected chip/ghost never in actuals; Checklist header + tick=pay/realize; CC task → Statement day typed link; funding under More/Checklist not a fifth pane; Cookie Jar in More with running balance / who’s-paid / no nag. Engines + accept fixtures before chrome. | Skills Operate/Humanizer/Emil/UI UX Pro Max; `docs/SKILLS_REVIEW.md`. |
| 2026-08-29 | **Phase 4 Slice A** shipped: `Projection` / `Forecast` / `Checklist` engines; `RecurringRuleRecord`; Bills panes Split·Forecast·Checklist·Love Tab (short Seg labels, shared cycle); Things We Keep Doing read-only; Receipts Projected filter/ghost. Typical variable placeholder ₱8,000 until rules refine it. | Spec §6 Phase 4 first slice; skills plan pass. |
| 2026-08-29 | **Bills + Receipts UI polish:** Seg equal-width for ≤4 options; Split CTAs under settle/Fern with `Spacing.md`; Forecast shortfall inside verdict + stacked math (no booked footer when lists exist); Receipts people row + Filters sheet (Pending/Projected short labels). | Thumb reach / density; Operate pass after Slice A. |
| 2026-08-29 | **Receipts hygiene:** List swipe leading = Edit (Add form edit mode), trailing = Delete + confirm; hard delete; settlementRole rows Delete-only. Soft delete stays Phase 8. | Smoke without reinstall; Operate/Emil/HIG. |
| 2026-08-29 | Receipts contribution rows: leading Edit opens amount-only sheet (keeps `settlementRole`); receivable / fundMove / loanPayment stay Delete-only. | Fix mistyped contributions without full Add form. |
| 2026-08-29 | **Pause after Phase 4 Slice A** (+ polish + Receipts hygiene). Slice B funding / Slice C Cookie Jar not started. | Explicit stop; resume at B when ready. |
| 2026-08-30 | **Phase 4 Slice B** shipped: `Funding` engine + `FundingPlanRecord`; Forecast tranche lines (bill excluded); Checklist reserve/payout; Things We Keep Doing pause + plan status; PruLife demo `funded k/n → paid`. | Spec §4.9 accept walkthrough. |
| 2026-08-30 | Bills cycle picker unions funding tranche/payout anchors + next half-month (not ledger-only). | Forecast/Checklist can open second tranche cycle. |
| 2026-08-30 | Funding tranche Checklist tick posts realized half-expense; last reserve auto-**Paid**; no separate Pay task. Spec reserve bucket deferred to Funds. | Matches spreadsheet habit; avoids double-count of full bill. |
| 2026-08-30 | Checklist **Count it** sheet (How did you pay? + split when Shared); Things We Keep Doing **Add** (Just Fern/Stark/Shared, optional 2-cycle set-aside); twin personal PruLife seed. | Payment method per tick; anti-double personal vs shared. |
| 2026-08-30 | **Supersedes** “payment method per tick”: Count it **prefills** rule/task default account; **Change** only if this payday differs. Keep doing this footer matches. Split/Paid by still when Shared. | Setup owns default; Checklist is confirm+post (Operate). |
| 2026-08-30 | Things We Keep Doing: swipe **Edit** / **Delete** (+ confirm). Pause = temporary; hard delete rule + linked funding plan; Receipts untouched. Funding rewrite only when no tranche reserved. | Mistyped setup; match Receipts hygiene. |
| 2026-08-30 | Keep Doing Add/Edit: required **Category** picker (expense CoA; same SearchablePickList as Add). No global default category. | Per-rule category; Count posts correct CoA. |
| 2026-08-30 | Keep Doing validation error sits in **first Form section** (under title), not below set-aside. | Visible at medium detent without expand. |
| 2026-08-30 | **Phase 4 Slice C** shipped: `CookieJar` engine + `JarSourceRecord` + jar fields on transactions; More → Cookie Jar (running balance, who’s-paid, Still out / Returned); Add Cookie Jar toggle; demo units 404/406/408/305 + fixture rows. | Spec §4.13 accept: balance + IOU. |
| 2026-08-30 | Cookie Jar UX: no Clear chip (re-tap filter); confirm before Returned; **Add to the jar** sheet from `+`. Full utility bills on Receipts; unit reimbursements = jar **In** only (anti-double-dip). | Household internet/water + unit shares use case; Operate. |
| 2026-08-30 | Cookie Jar on Add/Edit: force **Petty Cash** (system) + **Just mine** (Fern). Not 50·50. YTD/charts later key off `jar.kind`, not category flow. | Avoid Stark due on unit In; Petty Cash isn’t CoA income/asset. |
| 2026-08-30 | **Phase 5 UX locks (pre-build):** More → Baggage + War Chest first-class; Baggage derived balance only (no hand-type); Checklist loan via Count it; raid sheet intentional (absorb default); snowball confirm + IOU repay before sweep; engines/fixtures before chrome. Funding tranche posts unchanged. | Skills Operate/Humanizer/Emil; `docs/SKILLS_REVIEW.md`. |
| 2026-08-30 | **Phase 5 Slice A** shipped: `Loan` engine + `LoanRecord`; More → Baggage We're Carrying (active/archive/journal); Checklist `loan_payment` + Count it bumps `paidMonths`; UB Personal seed 24/60 → ₱628,916.76. | Spec §4.11 / §6 accept. |
| 2026-08-30 | Loan Count it: **Paid from starts empty** (Choose) — no prefill from `paymentAccountId`. Count it sheet binds `countIt ?? item` so account pick updates on first return. Checklist toggle stays on while Count it is open (`pendingTaskId` + same-frame `armedTaskId`). | Operate; avoid false “retention” from seed default; sheet(item) nil flash. |
| 2026-08-31 | **Phase 5 Slice B** shipped: `Fund` engine (raid order, IOU absorb/add-to-due, repay oldest-first); `FundRecord` + demo Loan payoff / Sinking / Emergency; More → War Chest; Forecast over → Borrow sheet; fund_move ledger + optional Stark due. | Spec §4.10 accept: raid IOU attribution. |
| 2026-08-31 | War Chest: **Add fund** + **Top-up** (ledger Fund Move + `balanceC`); cards show home account; Borrow picks **destination** (Fern cash/bank/e-wallet) with two-leg Fund Move home→dest + free-text use note (default Cover bills). Repay still fund-record only (no reverse ledger yet). | Operate; envelopes need real setup; Phase 6 owns account balances. |
| 2026-08-31 | War Chest Add UX: **Start a fund** list footer (no leading `+` beside Back); Home picker = Fern asset pockets only (cash/bank/e-wallet/digital bank — no CC/loan); owner stays payer. Contributor funds and Baggage→fund link deferred. | Operate/Emil; §4.10 / §7.7. |
| 2026-08-31 | War Chest: **When it happened** = Add-style **compact** DatePicker; Start a fund / Top-up / Borrow sheets use **`.large`** detent so the calendar popover dismisses (wheel was a temporary anti-stick hack). | Match Add entry; Operate. |
| 2026-08-31 | MVP Borrow / raid UI is **absorb only** (payer). Hide Add to contributor’s due; `Fund.Attribution.addToDue` + `commitRaid` branch retained unused. No Stark wallet picker. | Raids = Fern covers bills; add-to-due needs settlement design later. |
| 2026-08-31 | Receipts: deleting an opening `fund_move` (`Fund.openingNoteMarker`) confirms remove **fund + all linked Fund Moves**. Demo seed fund balances stay ledger-free fixtures until Balance Day. | Operate; avoid orphan moves. |
| 2026-08-31 | `Fund.effectiveBalanceC` = cash left (`balanceC`); raid already dips balance — do not subtract IOUs again. UI shows In the bank + owed back (no double-count “Feels like”). | Review before merge PR #1. |
| 2026-08-31 | **Ship flow** (`.cursor/rules/ship-flow.mdc`): branch → implement → docs same pass → verify → commit (when asked) → push → PR → review/fix → ready → merge → update local `main`. No PR before push; no deferred docs. | Locked after PR #1; corrects inverted “PR then docs then commit” habit. |
| 2026-08-31 | **Phase 5 Slice C** UX: War Chest snowball queue + Sweep confirm (IOU repay before loan-payoff park); Baggage chips read-only; Ready to pay → Checklist; Forecast breathing room → Sweep; no drag-reorder; no Statement-day snowball payout. | Skills Operate/Humanizer/Emil; `docs/SKILLS_REVIEW.md`. |
| 2026-08-31 | **Phase 5 Slice C** shipped: `Snowball` engine (queue/batches, proposeSweep IOU→park, ready-to-pay, park-another-month); War Chest Snowball + Sweep; BPI remnant seed; Forecast leftover link. Phase 5 A+B+C complete. | Spec §4.10 / §6 repay-before-sweep accept. |
| 2026-08-31 | Park another month: **confirm sheet** with From (default loan-payoff home) + date; Sweep From defaults to same home. No silent first Cash pocket. | Follow-the-money; Operate. |
| 2026-08-31 | **Accounting map gate** (`.cursor/rules/accounting-map.mdc`): before any money-moving feature, name pockets / envelope / ledger legs and report followability; push back if it worsens dual books or same-sign transfer theater. | Charts/reports must follow the money. |
| 2026-08-31 | Snowball edit chrome: sheet **Edit payoff order**; labeled Order/Batch sections; list `Pay next · #`; Ready to pay copy without “from”. | Operate/Humanizer; unlabeled twin fields. |
| 2026-08-31 | Loan strategy **display**: Stash extras / On schedule only (`DisplayLabels`); raw `prepay` / `park_to_maturity` unchanged. | Humanizer; Prepay/Park-to-maturity jargon. |
| 2026-08-31 | Snowball **Batch** UI hidden until a later wave exists (`Snowball.showsBatchChrome`); edit offers “Pay in a later wave…”. | Operate; one-wave demos. |
| 2026-08-31 | Park/Sweep sheets dismiss only after successful commit (Forecast leftover keeps War Chest open on failure). | Review before merge PR #3. |
| 2026-08-31 | **Input bounds hygiene:** fund + Keep Doing titles use display-name clamp (≤40); borrow/journal notes use note clamp (≤200); snowball order/batch via `clampQueueIndex` **1…99** (empty order → nil). Rule `.cursor/rules/input-bounds.mdc` + skill `input-bounds-hygiene`. | Close unbound TextFields; shared engine only. |
| 2026-08-31 | **Phase 6 UX locks (pre-build):** slices A Balance Day/Snapshot engine → B Empire charts → C YTD/drift/Money Sleeps; pocket truth on Balance Day; spoken-for = envelopes on home (not double assets); household netting in engine; metrics cards before charts; interest drift never silent (C). | Skills Operate/Humanizer/Emil/accounting-map; `docs/SKILLS_REVIEW.md`. |
| 2026-08-31 | **Phase 6 Slice A fixtures gate:** Portfolio-Fern 08/20 + NW −₱151,537.98 must be supplied before Slice A accept tests; do not invent from prototype mocks. | Spec §6 accept is numeric; numbers not in-repo yet. |
| 2026-08-31 | **Portfolio-Fern 08/20 golden** (`PortfolioFern0820`): Fern personal seven metrics locked from spreadsheet NW table (NW −₱151,537.98). Sheet line list does not sum to totals — manual mess parked; no bridging formula. Negative NW is valid MVP state. | Spec §6 accept; Balance Day owns future consistency. |
| 2026-08-31 | **Phase 6 Slice A** shipped: `Snapshot` engine + `SnapshotRecord`; More → Our Little Empire (metrics cards + Check the balances); lastConfirmed on accounts; Preprod demo load of Fern 08/20 metrics. Charts/YTD/drift deferred. **Balance Day “type all pockets” superseded** → 2026-08-31 Empire dashboard reshape. | Spec §4.6 / skills locks. |
| 2026-08-31 | Empire filter = **Fern · Stark · Household** peer Seg (not Personal/Household nested under a person). Household nets internal debts; Balance Day stays per-person. | Operate; nested Seg read as “Fern’s household.” |
| 2026-08-31 | **Empire dashboard reshape:** Empire is a **read-only** live pocket dashboard (`PocketBalance` from ledger / loan / lastConfirmed); Balance Day is **thin** (externals only); Shared externals confirm **once on Fern**; tap pocket → mini-report (no edit). **Supersedes** Slice A “type every pocket on Balance Day.” | Operate + accounting-map; dual-edit was a second book. |
| 2026-08-31 | PocketBalance v1: asset = income/savings/sinking/transfer − expense; liability CC opposite; loans derived; externals lastConfirmed; spoken-for display-only. Fund Move dual-leg skew accepted until transfer model. | Honest follow-the-money; don’t invent fixes. |
| 2026-08-31 | Empire **Cycle** Menu (Bills-style anchors): pocket NW **as-of** cycle end; mini-report lists that cycle’s window; missing snapshot → ledger. Label Cycle not statement date. Balance Day stamps Empire’s selected cycle. | Operate; in-window-only would wipe NW; Statement day owns CC paper. |
| 2026-08-31 | PocketBalance **excludes** `contribution` / `receivable` / `fund_move` legs from pocket sums; Love Tab line from `Settlement.history` (internal debt). Loan payments still count. | Settlement theater must not inflate House cash / NW. |
| 2026-09-01 | Portfolio-Fern **metrics-only demo** shows Spec golden when Cycle matches its anchor (`2026-08-20`), even if seed pockets exist; other cycles stay live ledger. | Smoke button was a no-op while live pockets always won. |
| 2026-09-01 | **Phase 6 Slice B** shipped: Empire Swift Charts — NW line + assets/liabilities area from `SnapshotRecord` series (+ live tip); negative Y domain; tap selection readout; Reduce Motion static. No dual-axis Δ overlays; no savings line; no invented history. | Spec More Empire charts; spreadsheet samples adapted for phone. |
| 2026-09-01 | Empire **sticky flair:** above-fold NW hero + compact sparkline (blush on gain); full charts below; rose heart pulse on positive Δ; ease-out draw reveal (static under Reduce Motion); deltas under DisclosureGroup. Cheese stays off amounts. | Charts were below the fold; Spec §1 one micro-moment; Operate compact metrics. |
| 2026-09-01 | Empire **hybrid hero** (supersedes sparkline-beside-NW): full-width NW line above fold + selection tooltip (date / NW / step Δ); Assets\|Liabilities compact under it; A/L chart only below; Cycle Menu unchanged. No dark/orange skin, no Day/Week/Month chips, no row sparklines. | Energy+hedging composition refs; Spec light-mode + cheese quarantine. |
| 2026-09-01 | **Phase 6 Slice C** pre-build: YTD first (realizedDate year; split/just-mine; bars+donut+Needs/Wants; exclude Fund Move theater); interest-drift confirm never silent; Money Sleeps = scoped account map not second Empire. Soft modern composition only. | Skills Operate/Humanizer/Emil/accounting-map; `docs/SKILLS_REVIEW.md`. |
| 2026-09-01 | **Phase 6 Slice C** shipped (YTD cut): `YearSoFar` engine + Our Year So Far UI; `InterestDrift` + Balance Day confirm sheet; Where the Money Sleeps account map. | Spec More YTD/drift/Money Sleeps; accounting-map exclusions. |
| 2026-09-01 | YTD chrome matches Empire: **Fern · Stark · Household** peer Seg; Split/Just mine only on personal tabs. Household YTD = each realized leg **once at full `amountC`** (never Fern-split + Stark-split). | Operate consistency; no double-count couple cashflow. |
| 2026-09-01 | **History windowing:** store all cycles; Cycle Menus / Empire chart series window by **year** (`Cycle.anchors(inYear:)` / `EmpireCharts.points(inYear:)`); `recentAnchors` fallback. Receipts deep virtualization / Import chunking still later. | 10y imports must not dump ~240 cycles into a Menu. |
| 2026-09-01 | Where it Went uses **rank palette** in `Colors.categorySlice` (terra → amber → olive → slate teal → cocoa → muted Other) + center spend total — not Charts auto blue. Aesthetic retune later via tokens only. | Spec warm-paper; inspiration thick-ring layout without purple/hatch. |
| 2026-09-01 | **Our Year So Far Quiet ledger (1c):** flat hairline sections; year in nav; underline Fern·Stark·Household; Split/Just mine mini-toggle on hero; **Spent = ink, Earned = quiet green only**; bar fills use quietAccent + expenseBar clay (not amount color). Trailing 3‑month expense average + spike caption. Donut center = top-category %. Keeps Fraunces pet title + Needs & wants. **Supersedes** YTD expense-amount terracotta for this screen. | Redesign 1c; Spec cheese title retained; amount-color collision fix. |
| 2026-09-01 | YTD **12-month demo seed** (`YearSoFar.demoRows` + `SeedCatalog.seedDemoYearSoFarIfNeeded`): additive realized legs for current year; Preprod load button; idempotent ids `ytd-demo-{year}-*`. | Quiet ledger charts need a full year to smoke; don’t invent Fund Move theater. |
| 2026-09-01 | YTD polish: hero/list amounts **scale for millions**; thinner donut (`innerRadius` 0.78); Needs·Wants·**Savings** row (`savings`/`sinking` flows); usual line = **prior** up-to-3 months (not including latest); charts keyed to lens/scope. App chrome: paper ground `#FAF8F5` on tab bar + nav appearance. Demo ids `ytd-demo-v2-*`. | Quiet ledger 1c follow-ups; paper vs system grey. |
| 2026-09-01 | Balance Day demo externals: `seedDemoExternalsIfNeeded` adds Spec-named PruLife / Philstocks / GoTrade / CoinsPH / Pag-IBIG MP2 (Fern) + Maya Invest (Stark) with prefilled `lastConfirmedBalanceC`. Button becomes **Update investments**. | Empty “Nothing external” smoke; Spec §4.6 prefilled tier. |
| 2026-09-01 | **Quiet ledger on Home / Receipts / Empire:** same 1c system as YTD (paper, 20pt, hairline sections, `quietAccent`). **Titles stay cheese** (Fraunces Home / The Receipts / Our Little Empire; Add to the pile). Amounts are **ink**; only income is green. Home **Due next** = next cycle(s) `Forecast.committed` (skips an empty half-month); display-only. Receipts TBD drawer kept. Empire keeps Balance Day, pockets, demo. No tab-bar restyle; no loading skeletons. | Redesign folder 2a–2d; YTD precedent for titles. |
| 2026-09-01 | Empire **as-of** is one **cycle wheel** (15th / month-end only, full date label incl. year). Separate Year + Cycle menus removed. `selectedYear` still derives from the chosen anchor for chart windowing (`EmpireCharts.points(inYear:)`). Wheel list capped at 48 via `Cycle.recentAnchors` when history is large. | Nav clutter; cycle model is half-month anchors, not arbitrary days. |
| 2026-09-02 | **Quiet ledger on Add / Bills:** same 1c paint (paper, 20pt, hairline sections, `quietAccent`, 40pt hero). Add drops stacked cards for ruled rows; custom split disables Save until legs add up. Bills uses underline tabs; one hero per pane (Still open / verdict / tab balance; Checklist keeps the count line); cycle picker in nav. **Titles stay cheese** (Fraunces *Add to the pile* / *Whose Turn Is It*). No chat, type picker, recurring, Split stacked chart, or Love Tab area chart. | Redesign Add+Bills 3a–3b; titles follow Home/Receipts/Empire lock. |
| 2026-09-02 | **Quiet ledger on Money Sleeps / War Chest:** same 1c paint. Pockets get a count + spoken-for subtitle, **no 40pt total** (would restate Empire NW and double-count envelopes). Funds hero is **Owed back** (`iousC` sum) at 40pt ink; per-fund cash stays on the row. **Titles stay cheese** (Fraunces *Where the Money Sleeps* / *The War Chest*). Snowball queue + Edit/Park stay; Borrow stays enabled; Sweep leftover stays on the chest. Empty pockets CTA opens The Fine Print. No new Fund Moves, no household funds, no add-to-due. | Redesign 4a–4b; spoken-for remains display-only. |
| 2026-09-03 | Cycle / year pickers are **wheel sheets** (Cancel + Done): Empire, Bills, Our Year So Far. Shared `QuietWheelSheet`. Bills list capped at 48 like Empire. No live-apply while spinning. | Consistency; Menu dumped every half-month. |
| 2026-09-03 | YTD demo years are **current + prior** (`YearSoFar.demoYears`). Seed and year wheel include both so the picker is not a single year. | Year wheel needs something to show. |
| 2026-09-03 | **Quiet ledger onboarding 6a:** three steps (names + PHP chip, roles, starters). Pet title stays cheese (Fraunces *Shall we dance?*, 34pt on this screen only). Currency is display-only `PHP · ₱`, no picker. Continue stays enabled; names validate on tap. Starter preview is computed from `SeedCatalog` + live names. | Redesign 6a; For later *Currency other than PHP*. |
| 2026-09-03 | **Copy humanizer:** user-facing strings drop em/en dashes and curly quotes. Personal account labels use ` · ` (same as DisplayLabels), still computed never stored. Empty placeholders use `-`. | Humanizer pass; productization law unchanged. |
| 2026-09-05 | **Accounts catalog:** More → **Accounts** (was *Where the Money Sleeps*) is pockets + **What it was for** create/edit. DM Sans title, not Fraunces. Keep live pocket map, spoken-for, no 40pt total. Shape/tags lock when in use; rename always. User kinds exclude loan/receivable. Fine Print is names/pets/roles only; accounts list and CoA oddities UI gone (`CoAMigration` engine kept). No delete. Empty Add lives on Accounts. **Supersedes** cheese title + Fine Print empty CTA from 2026-09-02 Money Sleeps row. | Operate; one room for instruments; accounting-map. |

## For later

Do not implement until a human moves the row to Baseline.

| Date | Item | Notes |
|---|---|---|
| 2026-08-23 | Android / Play Store | Do not add now. |
| 2026-08-23 | iPad, landscape, Split View, Stage Manager | iPhone-only until then. |
| 2026-08-23 | Team ID, signing details, App Store category copy, screenshots, privacy nutrition labels (draft content) | Wire with Apple Developer account; category Finance; nutrition labels must disclose PostHog. |
| 2026-08-23 | Face ID / passcode lock on open | Nice for a ledger; not MVP. |
| 2026-08-23 | Home Screen widgets, Live Activities, Apple Watch, Lock Screen | Native surfaces beyond MVP. |
| 2026-08-23 | iCloud Drive as a backup destination / CloudKit | Phase 8 sync path still Supabase-named; revisit later. |
| 2026-08-23 | Push / local notifications for cycle due, checklist leftover, Love Tab nudge | Spec forbids nagging. Design copy first if opened. |
| 2026-08-23 | BGTaskScheduler for backups | Unreliable; on-open cadence is Baseline. |
| 2026-08-23 | Dark mode | Spec is light mode only. |
| 2026-08-23 | Web / desktop companion | App Store is the product. |
| 2026-08-29 | Capacitor + React / Vite rewrite | Only if SwiftUI path is abandoned; inverse of prior For-later SwiftUI row. |
| 2026-08-31 | Raid **add-to-due** UI (and House cash box posting fix) | Engine `Fund.Attribution.addToDue` retained; re-show after settlement design. Not a Stark wallet picker. |
| 2026-08-23 | Household-scoped funds | Spec: personal-scope in MVP. |
| 2026-08-23 | Swappable payer / contributor roles | Spec §7.9. |
| 2026-08-23 | Third person / family seat | Spec §7.1. |
| 2026-08-23 | Currency other than PHP | Spec §2. |
| 2026-08-23 | Impeccable before-edit hook | Optional: `npx impeccable install --providers=cursor --scope=project`. |
| 2026-08-23 | App Review edge cases (export compliance, account deletion, support URL) | Handle when first TestFlight/App Store listing is prepared. |
| 2026-08-29 | Freemium / StoreKit IAP | Rejected for MVP; reopen only if monetization model changes. |
| 2026-08-29 | NetworkMonitor / SoundService / EmojiPicker from Uswag | Not in vibe. |
| 2026-08-29 | Rename SwiftData/`purchaseDate` → `occurredDate` (or similar) | UI already says “When it happened”; schema rename needs migration. |

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
| [emilkowalski/skills](https://github.com/emilkowalski/skills) | `emil-design-eng`, `animate`, `apple-design`, `write-swift`, … | Motion, Apple HIG, Swift. |
| [obra/superpowers](https://github.com/obra/superpowers) | TDD, plans, debugging, review | Engine work and phase execution. |
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | `.cursor/skills/ui-ux-pro-max` | UX rules; stack notes are not product law. |
| Uswag playbook copy (2026-08-29) | `.cursor/skills/greenlight` | App Store pre-submit scan. |
| Uswag playbook copy (2026-08-29) | `.cursor/skills/humanizer` | De-AI listing and cheese copy. |
| Uswag playbook copy (2026-08-29) | `.cursor/skills/aso-appstore-screenshots` (+ `compose.py`) | ASO frames 1290×2796. |

Refresh Taste / Emil / Superpowers with `npx skills update -p -y`. Greenlight / Humanizer / ASO: re-copy from the Uswag skills tree when needed.
