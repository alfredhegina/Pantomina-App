# Pantomina — Phase 7 PRD

**Status:** Slice A shipped 2026-09-05 · Rooms B/C still spec until artboards  
**Audience:** design + implement  
**Law:** `APP_SPEC.md` §1–2, §4.12, §4.14, §5, §6 Phase 7 · `docs/DECISIONS.md`  
**Artboards:** [`redesigns/pantomina-phase-7/Pantomina Phase 7 Artboards.dc.html`](../redesigns/pantomina-phase-7/Pantomina%20Phase%207%20Artboards.dc.html) (Room A, A1–A7)

If this file and the spec disagree, stop and ask. Do not implement For-later rows.

Phase 6 is complete. Phase 7 is the last MVP phase before TestFlight. Phase 8 sync is out of scope.

---

## 1. Problem

Add is a Quiet-ledger **form**. Capture from a sentence, from Shortcuts, and a restorable backup do not exist yet. Fine Print is names / pets / roles only.

Phase 7 ships three product rooms, then a polish + App Store readiness pass:

1. **Chat capture** on Add (form stays as Fix something / fallback) — **Room A, locked**
2. **Unconfirmed inbox** on Receipts (Shortcut / App Intent drafts) — Room B, spec until artboards
3. **AI key + backup / restore** on The Fine Print — Room C, spec until artboards; one chrome pick already made
4. **Vibe / a11y / empty-error audit** and Archive-ready build

---

## 2. Goals and non-goals

### Goals

- Type a sentence → see a **confirmation card** → Save. Never auto-save.
- Same pipeline offline with **no Gemini key** (local rules).
- Optional BYO Gemini key in **Keychain** (never SwiftData, logs, screenshots, or backups).
- Shortcuts / App Intents land in an **inbox**, not the ledger, until confirmed.
- Full-fidelity **JSON backup** that round-trips; **CSV** is export-only.
- Restore preview → Replace or Merge; Replace is type-to-confirm; newer schema is refused.
- Every shipped screen has a designed empty and error state. 44pt targets. Reduce Motion honored.
- Xcode can **Archive** Preprod/Prod for TestFlight (upload may wait on signing).

### Non-goals

| Parked | Why |
|---|---|
| Phase 8 sync / Supabase / two-device | Post-MVP |
| Dark mode, iPad, widgets, Face ID, push | For later |
| Household funds, raid add-to-due, swappable roles | For later |
| Type picker or recurring toggle returning to Add | Quiet ledger 2026-09-02; Keep Doing owns habits |
| Age-gate wall for Gemini | Legal revisit, not a locked screen |
| Chat as a fifth tab or a messenger transcript | Capture, not conversation |
| Sarcastic / punish / AI-as-judge coach | Shame-free vibe; Gemini is a parser only |
| **Home last-cycle commendation strip** | After Phase 7. See §14. |
| Inventing the three golden utterances | Lock into `APP_SPEC.md` §4.12 before Slice A accept tests |

---

## 3. Users and voice

Two people, ids `fern` (payer, sage) and `stark` (contributor, terracotta). UI always uses **display names**, never ids.

Cheese only in: screen titles, empty/success/nudge copy, one blush accent, at most one micro-moment per screen. Never on amounts, card field labels, errors, or destructive actions.

**Banned in UI:** realize / realized, projection / actuals, pull / raid, record / row, upsert. Say counts, spoken for, becomes real, cover it from a fund.

Copy: sentence case; no em/en dashes or curly quotes; empty placeholder `-`; personal labels use ` · `. Errors stay un-cheesy.

---

## 4. Design system (locked)

Quiet ledger **1c**. Light mode only. iPhone 393 × 852 artboards. Paper ground.

| Token | Value |
|---|---|
| Ground | `#FAF8F5` |
| Card | `#FDFDFC` |
| Ink | `#1D212B` |
| Muted | `#6A7181` |
| Hairline | `#E9E7E2` |
| Fern | sage `#498D6D` (deep `#3B7157`) |
| Stark | terracotta `#EF8F6C` |
| Type | Fraunces italic pet titles · DM Sans UI · tabular amounts |
| Amount hero | 40pt ink |
| Touch | 44pt minimum |
| Currency | PHP `₱` only; 2 decimals on cards |

**Add sheet chrome (artboards + Baseline 2026-08-29):** grabber, interactive pull-down dismiss, **no Cancel**, no keyboard Done. Save resigns focus. Current code’s Cancel is superseded for this sheet.

**Icons:** spec still says Phosphor; the shipped app uses SF Symbols. Implement native with SF Symbols unless that decision is reopened.

**Input bounds:** note ≤200 graphemes; money ₱1…₱100,000,000; display names ≤40. Engine only.

---

## 5. Slice shape

A **Phase 7 Room A UX lock** is in `docs/DECISIONS.md`. **Slice A shipped** (offline parser + A1–A7). Rooms B/C use spec until their artboards land; do not invent B/C chrome.

| Slice | Scope | Artboards | Accept focus |
|---|---|---|---|
| A — Capture | Local rules parser + confirmation cards + ambiguity + batch | A1–A7 shipped | Offline cards from locked §4.12 utterances |
| B — Inbox + BYOK | App Intents / Shortcuts → inbox; Keychain Gemini | Not drawn | Same pipeline; empty key = fallback |
| C — Backup / restore | JSON + CSV; cadence; preview; Replace/Merge; refuse newer schema | Not drawn. Last 5 autos = **visible list with dates** | Round-trip + derived metrics |
| Then | Vibe / a11y / empties; Archive | — | Checklist + no PII in logs |

Accounting-map gate: chat Save posts the **same ledger path as the form**. Do not invent a parallel book.

---

## 6. Room A — Chat capture (locked)

**Job:** free text → parsed draft → **confirmation card** (never auto-saved) → one-tap Save, or Fix something opens the existing Quiet-ledger form prefilled.

**Composer is the sheet.** Fix something **pushes** the prefilled form as a **second screen** (A7), not a toggle on the same page.

Utterances, Fern / Stark, CoA items, and account names in the artboards are **stand-ins**. Not golden. Not for tests.

### A1 — Composer, empty

- Title: Fraunces *Add to the pile* / “New entry”
- Composer card placeholder: **Say it the way you would say it out loud**
- 44pt send control (arrow), muted until there is text
- Eyebrow **Things that work**: last three saved typed utterances, padded with the §4.12 goldens
- Footer text button: **Fix something by hand** (opens A7 empty / unparsed)

### A2 — One confirmation card

- Recap chip of the utterance + **Edit** (returns to composer)
- Card: 40pt amount, merchant caption, ruled rows:
  - Category
  - Payment method
  - Paid by (person dot + name)
  - Whose is it (`50 · 50` / Just mine / Custom)
  - When it counts (`Counts on {date}` or `Waiting on statement · counts on {date}`)
- Sticky **Save** (ink fill) · **Fix something** (sage text)
- Never auto-save

### A3 — One ambiguity question, inline

- Exactly one question, **on the card**, as a two-choice row. No sheet. No quiz.
- Example shape: “Which card, BPI or BPI · Fern?” Use live names, never ids.
- Unresolved: When it counts shows `-`. **Save is disabled** (muted fill) until a choice is made.
- Fix something still available

### A4 — Batch, carousel with count header

- Recap of the whole message + Edit
- Header: human count (“Three things in there”) + tabular **1 of 3**
- Horizontal carousel of cards; peek the next card; page dots
- Each card has its own Save / Fix something. Each Save is independent.
- Footer muted: **Saved ones drop off the stack**

### A5 — Couldn’t parse

- Recap + Edit
- Card: **No amount in there.** Muted: **Add a number and a merchant, or fill it in by hand.**
- **Try again** (outline) · **Fill it in by hand** (opens A7)
- No cheese on the error

### A6 — Offline, no key (same layout as A2)

- Muted line under the recap: **Using built-in shortcuts**
- Same card chrome. Optional extra settlement line in muted prose when it is a contribution, using live names (stand-in: “Stark's 7,500 goes against what Stark is spoken for this month.”)
- Empty Gemini key = this state. Do not block. Do not show a “AI is off” wall.

### A7 — Fix something → existing form, prefilled

- Back (sage) to the composer / card
- Title: Fraunces *Fix something*
- Existing Quiet-ledger form: 40pt amount, ruled Category / Pocket / Paid by / Whose is it (Just mine · 50 · 50 · Custom) / When it happened / Note / Cookie Jar
- **No type picker. No recurring toggle.** Prefill from the draft. Sticky Save.

### Shorthand memory

Corrections persist as merchant/keyword mappings. No settings list in MVP chrome.

---

## 7. Room B — Unconfirmed inbox (spec; artboards not in this lock)

Holding tray for captures that were **parsed but not saved**. Not a second ledger. Not TBD.

| Surface | What | Status language |
|---|---|---|
| TBD drawer (exists) | CC swipes waiting on Statement day | Not counted yet |
| Inbox (new) | Parsed drafts not on the ledger yet | Unconfirmed. Never “pending” |

- Badge on Receipts for inbox count
- Same parse pipeline as in-app chat
- “Swept at day’s end” = review queue, **not** auto-post
- Capture door is Shortcuts / App Intents, not a public webhook
- Tap a row → same Save / Fix something as Room A

Do not draw or invent B chrome until Room B artboards exist. Engine work may proceed from this table.

---

## 8. Room C — Fine Print: AI + backups (spec; one chrome pick)

### AI (advanced) — collapsed by default

- Label: AI entry (advanced)
- Sub: Bring your own Gemini key, or leave off
- Masked field, Show / Hide, **Test key**, **Clear**
- Copy (muted): stored on this device only; never synced, never logged, never in backups; bills their Google account; leave empty and entry still works via built-in shortcuts

### Backups

**Cadence Seg:** Off · Daily · Weekly · Bi-weekly (15th and 30th). Checked on **app open and foreground**, plus **Back up now**.

**Last 5 auto-backups:** **visible list with dates** (picked 2026-09-05; not drawn yet).

Two artifacts (muted copy; user does not pick a restore format):

| File | Role |
|---|---|
| Schema-versioned JSON envelope | Full fidelity. Only restorable format. |
| CSV bundle | Spreadsheet-friendly. Export-only. Not restorable. |

Files leave via share sheet / Files / document picker.

**Restore:** pick JSON → validate schema + checksum → preview (entity counts, date range, person names, app version) → Replace everything or Merge (upsert by id, newer `updatedAt` wins) → Replace is type-to-confirm → every restore auto-snapshots current data first → newer schema than the app is refused. Gemini key is never in the file.

Separate: **Export everything (CSV)**.

Prototype visual reference: `pantomina-app.jsx` Fine Print cards. Paint Quiet ledger. Do not port React.

---

## 9. Room D — Polish and App Store

- Full §1–2 vibe pass
- a11y: focus, contrast, 44pt, Reduce Motion
- Designed empty and error on every screen
- Usage-description strings as needed
- No debug logging of amounts, names, notes, merchants, Gemini text, backups, or Keychain
- Privacy nutrition labels drafted (PostHog Device ID when analytics ships)
- Archive-ready Preprod + Prod. Demo seeder compiled out of Prod.

`docs/app-store-checklist.md` is still not started. Screenshots wait on locked chrome.

---

## 10. Functional requirements

UI never reimplements rules. Engines are pure Swift, test-first.

| ID | Requirement |
|---|---|
| P7-1 | Parser returns a draft card; Save is an explicit user action |
| P7-2 | Rules fallback produces correct cards for the three sample utterances once those strings are locked in §4.12 |
| P7-3 | Ambiguity asks at most one question; Save stays disabled until answered |
| P7-4 | Batch → N drafts; each Save independent; saved cards drop off the stack |
| P7-5 | Shorthand mappings persist and apply next time |
| P7-6 | App Intent / Shortcut posts raw text to the same pipeline → inbox |
| P7-7 | Gemini key in Keychain only; absent = silent rules fallback + “Using built-in shortcuts” |
| P7-8 | JSON backup + CSV export; key never written |
| P7-9 | Cadence on open/foreground; keep last 5 autos as a dated list; Back up now |
| P7-10 | Restore preview; Replace (type-to-confirm) or Merge; pre-restore snapshot |
| P7-11 | Newer schema refused; older schema migrates |
| P7-12 | Round-trip: backup → wipe → restore ⇒ byte-identical entities and derived metrics (settlement, Love Tab, jar balance, snapshots) |

---

## 11. Spec gap — golden utterances

Locked in `APP_SPEC.md` §4.12 (event date in tests: `2026-09-05`). Product composer examples are those three strings. Artboard copy remains stand-in kinds only.

**Note:** after picking Fern's GCash on golden 2, Save stays off until a category exists. Use Fix something to finish that card.

---

## 12. Open on Rooms B/C (wait for artboards)

1. Inbox badge: Receipts only, Add too, or tab-bar?
2. Restore type-to-confirm string
3. Room B empty copy
4. Room C preview / Replace / refuse layouts

Room A §13 questions from the earlier brief are **closed** by the artboards (composer vs form, ambiguity inline, batch carousel, pull-down / no Cancel).

---

## 13. Acceptance (spec §6 Phase 7)

- Three sample utterances (once listed in §4.12) produce correct cards **offline** via rules fallback.
- Backup → wipe → restore ⇒ byte-identical entity sets and identical derived metrics (settlement, tab, jar balance, snapshots).
- A due cadence generates a backup on open.
- Restoring a newer-schema file is refused gracefully.
- Contrast / 44pt / Reduce Motion; every screen has a designed empty state.
- Xcode can Archive an installable build for TestFlight.

---

## 14. After Phase 7 — Home last-cycle note (parked)

Not in this phase. When reopened:

- Home strip **above Due next**, only when the **last closed cycle** improved vs the one before: fewer Want-tagged spends, or more `savings`/`sinking` flow.
- Local `YearSoFar`-style engine, cycle-windowed. No Gemini. No push. No streak. No punish (omit the strip if neither improved).
- Exclude `loanPayment` and system categories from Wants. Do not use the still-open cycle.
- One line of cheese; pesos stay ink. Tap may open Our Year So Far.

---

## 15. References

- `APP_SPEC.md` — §1 vibe, §2 tokens, §4.12 chat, §4.14 backup, §5 IA, §6 Phase 7
- `docs/DECISIONS.md` — Baseline; Quiet ledger; Add no-Close; Phase 7 Room A lock
- `docs/SKILLS_REVIEW.md` — Gemini BYOK; not roast prompts
- `redesigns/pantomina-phase-7/Pantomina Phase 7 Artboards.dc.html` — Room A
- `pantomina-app.jsx` — Fine Print AI + Backups reference only
