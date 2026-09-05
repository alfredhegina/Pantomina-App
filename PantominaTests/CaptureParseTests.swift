import Testing
@testable import Pantomina

@Suite("CaptureParse")
struct CaptureParseTests {
    private static let catalog = CaptureParse.Catalog.starters(fernName: "Fern", starkName: "Stark")

    @Test("golden 1: grocery Robinsons on BPI CC is a ready card")
    func goldenGrocery() {
        let result = CaptureParse.parse(
            CaptureGolden.grocery,
            catalog: Self.catalog,
            eventISO: CaptureGolden.eventISO
        )
        guard case .ready(let card) = result else {
            Issue.record("expected ready card, got \(result)")
            return
        }
        #expect(card.amountC == 300_000)
        #expect(card.merchant == "Robinsons")
        #expect(card.categoryId == "cat-groceries-household")
        #expect(card.accountId == "acct-bpi-cc-fern")
        #expect(card.paidBy == .fern)
        #expect(card.split == .justMine)
        #expect(card.settlementRole == nil)
        #expect(card.countsHint == "Waiting on statement · counts on Oct 15, 2026")
        #expect(card.saveEnabled)
    }

    @Test("golden 2: gcash is one question until a pocket is picked")
    func goldenGCash() {
        let result = CaptureParse.parse(
            CaptureGolden.gcash,
            catalog: Self.catalog,
            eventISO: CaptureGolden.eventISO
        )
        guard case .needPick(let draft, let question, let choices) = result else {
            Issue.record("expected needPick, got \(result)")
            return
        }
        #expect(draft.amountC == 32_000)
        #expect(draft.countsHint == nil)
        #expect(!draft.saveEnabled)
        #expect(question == "Which GCash, Fern or Stark?")
        #expect(choices.map(\.id) == ["acct-gcash-fern", "acct-gcash-stark"])

        let picked = CaptureParse.applyChoice("acct-gcash-fern", to: draft, catalog: Self.catalog)
        #expect(picked.accountId == "acct-gcash-fern")
        #expect(picked.paidBy == .fern)
        #expect(picked.split == .justMine)
        #expect(picked.countsHint == "Counts on Sep 15, 2026")
        #expect(!picked.saveEnabled)
    }

    @Test("golden 3: stark put in posts as contribution on House cash box")
    func goldenContribution() {
        let result = CaptureParse.parse(
            CaptureGolden.contribution,
            catalog: Self.catalog,
            eventISO: CaptureGolden.eventISO
        )
        guard case .ready(let card) = result else {
            Issue.record("expected ready card, got \(result)")
            return
        }
        #expect(card.amountC == 750_000)
        #expect(card.categoryId == "cat-partner-contribution")
        #expect(card.accountId == "acct-house-cash")
        #expect(card.paidBy == .stark)
        #expect(card.split == .contribution)
        #expect(card.settlementRole == .contribution)
        #expect(card.allocFernC == 0)
        #expect(card.allocStarkC == 0)
        #expect(card.countsHint == "Counts on Sep 15, 2026")
        #expect(card.extraCaption == "Stark's 7,500 goes against what Stark is spoken for this cycle.")
        #expect(card.saveEnabled)
    }

    @Test("golden 1 posting uses the same realization path as the form")
    func goldenGroceryPosting() {
        let result = CaptureParse.parse(
            CaptureGolden.grocery,
            catalog: Self.catalog,
            eventISO: CaptureGolden.eventISO
        )
        guard case .ready(let card) = result,
              let post = CaptureParse.posting(from: card, purchaseISO: CaptureGolden.eventISO, catalog: Self.catalog)
        else {
            Issue.record("expected a posting from the grocery card")
            return
        }
        #expect(post.amountC == 300_000)
        #expect(post.accountId == "acct-bpi-cc-fern")
        #expect(post.categoryId == "cat-groceries-household")
        #expect(post.paidBy == .fern)
        #expect(post.allocation.fern == 300_000)
        #expect(post.allocation.stark == 0)
        #expect(post.realizedStatus == .pending)
        #expect(post.proposedRealizedDate == "2026-10-15")
        #expect(post.merchant == "Robinsons")
        #expect(post.settlementRole == nil)
    }

    @Test("incomplete gcash card cannot post until category exists")
    func gcashPostingBlocked() {
        let result = CaptureParse.parse(
            CaptureGolden.gcash,
            catalog: Self.catalog,
            eventISO: CaptureGolden.eventISO
        )
        guard case .needPick(let draft, _, _) = result else {
            Issue.record("expected needPick")
            return
        }
        let picked = CaptureParse.applyChoice("acct-gcash-fern", to: draft, catalog: Self.catalog)
        #expect(CaptureParse.posting(from: picked, purchaseISO: CaptureGolden.eventISO, catalog: Self.catalog) == nil)
    }

    @Test("no amount is a failed parse")
    func noAmount() {
        let result = CaptureParse.parse(
            "that thing from yesterday",
            catalog: Self.catalog,
            eventISO: CaptureGolden.eventISO
        )
        guard case .failed(let title, let hint) = result else {
            Issue.record("expected failed, got \(result)")
            return
        }
        #expect(title == "No amount in there.")
        #expect(hint == "Add a number and a merchant, or fill it in by hand.")
    }

    @Test("comma batch yields independent drafts")
    func batch() {
        let text = "\(CaptureGolden.grocery), \(CaptureGolden.gcash)"
        let result = CaptureParse.parse(text, catalog: Self.catalog, eventISO: CaptureGolden.eventISO)
        guard case .batch(let parts) = result else {
            Issue.record("expected batch, got \(result)")
            return
        }
        #expect(parts.count == 2)
        guard case .ready = parts[0], case .needPick = parts[1] else {
            Issue.record("expected ready then needPick")
            return
        }
    }
}

@Suite("CaptureUtteranceRecents")
struct CaptureUtteranceRecentsTests {
    @Test("empty storage shows the three goldens")
    func emptyShowsGoldens() {
        #expect(CaptureUtteranceRecents.display(raw: "") == CaptureGolden.examples)
        #expect(CaptureUtteranceRecents.display(raw: "[]") == CaptureGolden.examples)
    }

    @Test("one custom sits above the first two goldens")
    func oneCustomPadsGoldens() {
        let raw = CaptureUtteranceRecents.bump("meralco 2340 bdo jcb", onto: "")
        #expect(
            CaptureUtteranceRecents.display(raw: raw)
                == ["meralco 2340 bdo jcb", CaptureGolden.grocery, CaptureGolden.gcash]
        )
    }

    @Test("bumping a golden moves it to slot 1 without duplicating")
    func bumpGoldenDedupes() {
        var raw = CaptureUtteranceRecents.bump("custom 100 cash", onto: "")
        raw = CaptureUtteranceRecents.bump(CaptureGolden.gcash, onto: raw)
        #expect(
            CaptureUtteranceRecents.display(raw: raw)
                == [CaptureGolden.gcash, "custom 100 cash", CaptureGolden.grocery]
        )
    }

    @Test("comma batch round-trips as one recent")
    func commaBatchRoundTrip() {
        let batch = "\(CaptureGolden.grocery), \(CaptureGolden.gcash)"
        let raw = CaptureUtteranceRecents.bump(batch, onto: "")
        #expect(CaptureUtteranceRecents.decode(raw) == [batch])
        #expect(CaptureUtteranceRecents.display(raw: raw).first == batch)
    }

    @Test("case-insensitive dedupe keeps the latest casing")
    func caseInsensitiveDedupe() {
        var raw = CaptureUtteranceRecents.bump("GCash 320", onto: "")
        raw = CaptureUtteranceRecents.bump("gcash 320", onto: raw)
        #expect(CaptureUtteranceRecents.decode(raw) == ["gcash 320"])
    }

    @Test("empty and whitespace bumps are ignored")
    func emptyBumpIgnored() {
        let seeded = CaptureUtteranceRecents.bump("keep me 100", onto: "")
        #expect(CaptureUtteranceRecents.bump("   ", onto: seeded) == seeded)
        #expect(CaptureUtteranceRecents.bump("", onto: seeded) == seeded)
        #expect(CaptureUtteranceRecents.decode(CaptureUtteranceRecents.bump("   ", onto: "")).isEmpty)
    }
}
