# Phase 4 Slice C — Cookie Jar Implementation Plan

> **For agentic workers:** Execute task-by-task. TDD for engine.

**Goal:** Ship The Cookie Jar (§4.13): running-balance statement, JarSource who’s-paid strip, borrow IOUs with mark-returned, More entry + Add jar toggle.

**Architecture:** Pure `CookieJar` engine + SwiftData `JarSourceRecord` and jar fields on `TransactionRecord`. UI never reimplements balance math.

**Tech Stack:** SwiftUI + SwiftData + Swift Testing

**Spec:** `APP_SPEC.md` §4.13; `docs/DECISIONS.md` Phase 4 UX locks (More, no nag).

## Global Constraints

- Money = Int centavos; person ids `fern`/`stark`; light mode; no For-later.
- Engines pure; tests first; same-pass docs.

## Tasks

1. CookieJarTests (fixture running balance + who’s paid + IOU) → fail
2. CookieJar.swift engine → pass
3. Models + Bootstrap + seed units 404/406/408/305 + demo entries
4. CookieJarView + More link; mark returned
5. AddEntryView Cookie Jar toggle (source + spend/borrow)
6. DECISIONS / SKILLS / README
