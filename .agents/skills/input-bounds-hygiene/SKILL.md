---
name: input-bounds-hygiene
description: >-
  Audit and fix unbound TextFields against InputBounds. Use for hygiene passes,
  form bounds audits, or when deploying parallel agents to wire clamps.
---

# InputBounds hygiene pass

## When to use

- User asks for a hygiene / InputBounds / form-bounds pass
- A new sheet adds free-text or money fields
- Parallel agents should fix unbound fields without inventing limits

## Authority

- Limits live in `Pantomina/Engine/InputBounds.swift` + `docs/DECISIONS.md`
- Always-apply rule: `.cursor/rules/input-bounds.mdc`
- Spec + DECISIONS win on conflict

## Steps

1. **Inventory** — `rg 'TextField\(' Pantomina/Views` and cross-check each save path for `InputBounds.`
2. **Engine first** — if a new clamp API is needed, TDD in `PantominaTests/InputBoundsTests.swift`, then implement.
3. **Parallel fix** — one Task agent per independent view file (or cluster). Give each agent the exact unbound fields and the InputBounds API to use. Do not share session history; paste the rule table.
4. **Verify** — run InputBounds tests (and any touched UI compile). No completion claim without fresh output.
5. **Docs** — if a new lock (e.g. queue index range), add a dated Baseline row in `docs/DECISIONS.md` same pass.

## Parallel split pattern

```
Agent A — War Chest sheets (fund name, borrow note, snowball order/batch)
Agent B — Baggage journal
Agent C — Things We Keep Doing title
Coordinator — InputBounds API + tests + DECISIONS + merge
```

Use `dispatching-parallel-agents` for the inventory/fix agents; `subagent-driven-development` when executing a multi-task plan.

## Out of scope

- Inventing new product limits without a DECISIONS row
- Cursor Automations / scheduled loops (separate skill)
- Phase 6 money truth / accounting redesign
