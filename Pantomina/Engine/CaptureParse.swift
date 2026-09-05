import Foundation

enum CaptureGolden {
    static let eventISO = "2026-09-05"
    static let grocery = "home grocery Robinsons 3000 bpi cc"
    static let gcash = "gcash 320"
    static let contribution = "stark put in 7500"

    static var examples: [String] { [grocery, gcash, contribution] }
}

/// Last typed composer strings for Things that work. JSON so comma batches stay one row.
enum CaptureUtteranceRecents {
    static let slotCount = 3

    static func decode(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let items = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return items.filter { !$0.isEmpty }
    }

    static func encode(_ items: [String]) -> String {
        guard let data = try? JSONEncoder().encode(items),
              let text = String(data: data, encoding: .utf8)
        else { return "[]" }
        return text
    }

    static func bump(_ text: String, onto raw: String) -> String {
        let clamped = InputBounds.clampNote(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clamped.isEmpty else { return raw }
        var items = decode(raw)
        items.removeAll { $0.compare(clamped, options: .caseInsensitive) == .orderedSame }
        items.insert(clamped, at: 0)
        return encode(Array(items.prefix(slotCount)))
    }

    static func display(raw: String, goldens: [String] = CaptureGolden.examples) -> [String] {
        var rows = decode(raw)
        for golden in goldens where rows.count < slotCount {
            if rows.contains(where: { $0.compare(golden, options: .caseInsensitive) == .orderedSame }) {
                continue
            }
            rows.append(golden)
        }
        return Array(rows.prefix(slotCount))
    }
}

/// Offline rules parser for Add capture. UI never reimplements matching.
enum CaptureParse {
    struct Pocket: Equatable, Sendable {
        var id: String
        var baseName: String
        var scope: Scope
        var settlement: SettlementKind
        var statementCutoff: Int?
    }

    struct Category: Equatable, Sendable {
        var id: String
        var group: String
        var item: String
        var system: Bool
    }

    struct Catalog: Equatable, Sendable {
        var pockets: [Pocket]
        var categories: [Category]
        var fernName: String
        var starkName: String
    }

    enum Split: Equatable, Sendable {
        case justMine
        case fiftyFifty
        case contribution
    }

    struct Card: Equatable, Sendable {
        var amountC: Int
        var merchant: String?
        var categoryId: String?
        var accountId: String?
        var paidBy: PersonId
        var split: Split
        var settlementRole: SettlementRole?
        var allocFernC: Int
        var allocStarkC: Int
        var countsHint: String?
        var extraCaption: String?
        var saveEnabled: Bool
    }

    struct Choice: Equatable, Sendable {
        var id: String
        var label: String
    }

    enum Result: Equatable, Sendable {
        case ready(Card)
        case needPick(Card, question: String, choices: [Choice])
        case failed(title: String, hint: String)
        case batch([Result])
    }

    static func parse(
        _ text: String,
        catalog: Catalog,
        eventISO: String,
        extraKeywords: [String: String] = [:]
    ) -> Result {
        let chunks = text.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if chunks.count > 1 {
            return .batch(chunks.map { parseOne($0, catalog: catalog, eventISO: eventISO, extraKeywords: extraKeywords) })
        }
        return parseOne(text, catalog: catalog, eventISO: eventISO, extraKeywords: extraKeywords)
    }

    struct LedgerPosting: Equatable, Sendable {
        var purchaseISO: String
        var realizedDate: String?
        var realizedStatus: RealizedStatus
        var proposedRealizedDate: String?
        var amountC: Int
        var accountId: String
        var categoryId: String
        var paidBy: PersonId
        var allocation: Allocation
        var settlementRole: SettlementRole?
        var merchant: String?
    }

    /// Same AllocationRouting + Realization path the Quiet-ledger form uses.
    static func posting(from card: Card, purchaseISO: String, catalog: Catalog) -> LedgerPosting? {
        guard card.saveEnabled,
              let accountId = card.accountId,
              let categoryId = card.categoryId,
              let pocket = catalog.pockets.first(where: { $0.id == accountId })
        else { return nil }

        let intended: Allocation
        switch card.split {
        case .contribution:
            intended = Allocation(fern: 0, stark: 0)
        case .justMine:
            intended = AllocationDefaults.justMine(amountC: card.amountC, paidBy: card.paidBy)
        case .fiftyFifty:
            intended = AllocationDefaults.fiftyFifty(amountC: card.amountC)
        }
        let allocation = AllocationRouting.record(
            intended: intended,
            accountScope: pocket.scope,
            paidBy: card.paidBy
        )
        let decision = Realization.decide(
            purchaseISO: purchaseISO,
            settlement: pocket.settlement,
            statementCutoff: pocket.statementCutoff
        )
        let category = catalog.categories.first { $0.id == categoryId }
        let role: SettlementRole? = {
            if let existing = card.settlementRole { return existing }
            guard let category, category.system else { return nil }
            switch category.item {
            case "Partner Contribution": return .contribution
            case "Partner Receivable": return .receivable
            case "Fund Move": return .fundMove
            case "Loan Payment": return .loanPayment
            default: return nil
            }
        }()
        return LedgerPosting(
            purchaseISO: purchaseISO,
            realizedDate: decision.realizedDate,
            realizedStatus: decision.status,
            proposedRealizedDate: decision.proposedRealizedDate,
            amountC: card.amountC,
            accountId: accountId,
            categoryId: categoryId,
            paidBy: card.paidBy,
            allocation: allocation,
            settlementRole: role,
            merchant: card.merchant
        )
    }

    static func applyChoice(_ pocketId: String, to draft: Card, catalog: Catalog, eventISO: String = CaptureGolden.eventISO) -> Card {
        var card = draft
        guard let pocket = catalog.pockets.first(where: { $0.id == pocketId }) else { return card }
        card.accountId = pocket.id
        switch pocket.scope {
        case .fern:
            card.paidBy = .fern
            if card.split != .contribution { card.split = .justMine }
        case .stark:
            card.paidBy = .stark
            if card.split != .contribution { card.split = .justMine }
        case .household, .business:
            if card.split != .contribution { card.split = .fiftyFifty }
        }
        applyAllocation(&card)
        card.countsHint = countsHint(pocket: pocket, eventISO: eventISO)
        card.saveEnabled = isComplete(card)
        return card
    }

    private static func parseOne(
        _ text: String,
        catalog: Catalog,
        eventISO: String,
        extraKeywords: [String: String]
    ) -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = wordTokens(trimmed.lowercased())
        guard let amountC = firstAmountC(in: trimmed) else {
            return .failed(
                title: "No amount in there.",
                hint: "Add a number and a merchant, or fill it in by hand."
            )
        }

        if isContribution(tokens) {
            return contributionCard(amountC: amountC, tokens: tokens, catalog: catalog, eventISO: eventISO)
        }

        let paidHint = personHint(tokens: tokens, catalog: catalog)
        let matches = matchingPockets(tokens: Set(tokens), catalog: catalog, paidHint: paidHint)
        let categoryId = resolveCategory(tokens: tokens, extraKeywords: extraKeywords, catalog: catalog)
        let merchant = detectMerchant(in: trimmed)

        var card = Card(
            amountC: amountC,
            merchant: merchant,
            categoryId: categoryId,
            accountId: nil,
            paidBy: paidHint ?? .fern,
            split: .justMine,
            settlementRole: nil,
            allocFernC: amountC,
            allocStarkC: 0,
            countsHint: nil,
            extraCaption: nil,
            saveEnabled: false
        )

        if matches.count > 1 {
            let question = ambiguityQuestion(pockets: matches, catalog: catalog)
            let choices = matches.map {
                Choice(id: $0.id, label: AccountLabels.display(baseName: $0.baseName, scope: $0.scope, personName: personName($0.scope, catalog)))
            }
            return .needPick(card, question: question, choices: choices)
        }

        if let pocket = matches.first {
            card = applyChoice(pocket.id, to: card, catalog: catalog, eventISO: eventISO)
            return card.saveEnabled ? .ready(card) : .ready(card)
        }

        card.saveEnabled = isComplete(card)
        if card.accountId == nil && card.categoryId == nil {
            return .failed(
                title: "No amount in there.",
                hint: "Add a number and a merchant, or fill it in by hand."
            )
        }
        return .ready(card)
    }

    private static func contributionCard(
        amountC: Int,
        tokens: [String],
        catalog: Catalog,
        eventISO: String
    ) -> Result {
        guard let house = catalog.pockets.first(where: { $0.baseName.compare("House cash box", options: .caseInsensitive) == .orderedSame }),
              let cat = catalog.categories.first(where: { $0.system && $0.item == "Partner Contribution" })
        else {
            return .failed(title: "No amount in there.", hint: "Add a number and a merchant, or fill it in by hand.")
        }
        let paidBy: PersonId = tokens.contains("stark") || tokens.contains(catalog.starkName.lowercased()) ? .stark : .fern
        let name = paidBy == .stark ? catalog.starkName : catalog.fernName
        var card = Card(
            amountC: amountC,
            merchant: nil,
            categoryId: cat.id,
            accountId: house.id,
            paidBy: paidBy,
            split: .contribution,
            settlementRole: .contribution,
            allocFernC: 0,
            allocStarkC: 0,
            countsHint: countsHint(pocket: house, eventISO: eventISO),
            extraCaption: DisplayLabels.contributionSpokenFor(personName: name, amountC: amountC),
            saveEnabled: false
        )
        card.saveEnabled = isComplete(card)
        return .ready(card)
    }

    private static func isComplete(_ card: Card) -> Bool {
        guard card.amountC >= InputBounds.minAmountC, card.accountId != nil else { return false }
        if card.settlementRole == .contribution { return card.categoryId != nil }
        return card.categoryId != nil
    }

    private static func applyAllocation(_ card: inout Card) {
        switch card.split {
        case .contribution:
            card.allocFernC = 0
            card.allocStarkC = 0
        case .justMine:
            let a = AllocationDefaults.justMine(amountC: card.amountC, paidBy: card.paidBy)
            card.allocFernC = a.fern
            card.allocStarkC = a.stark
        case .fiftyFifty:
            let a = AllocationDefaults.fiftyFifty(amountC: card.amountC)
            card.allocFernC = a.fern
            card.allocStarkC = a.stark
        }
    }

    private static func countsHint(pocket: Pocket, eventISO: String) -> String {
        let decision = Realization.decide(
            purchaseISO: eventISO,
            settlement: pocket.settlement,
            statementCutoff: pocket.statementCutoff
        )
        let anchor = decision.proposedRealizedDate ?? decision.realizedDate ?? eventISO
        return DisplayLabels.settlementHint(isStatement: pocket.settlement == .statement, anchorISO: anchor)
    }

    private static func isContribution(_ tokens: [String]) -> Bool {
        tokens.contains("put") && tokens.contains("in")
    }

    private static func personHint(tokens: [String], catalog: Catalog) -> PersonId? {
        let fern = catalog.fernName.lowercased()
        let stark = catalog.starkName.lowercased()
        if tokens.contains("stark") || tokens.contains(stark) { return .stark }
        if tokens.contains("fern") || tokens.contains(fern) { return .fern }
        return nil
    }

    private static func matchingPockets(tokens: Set<String>, catalog: Catalog, paidHint: PersonId?) -> [Pocket] {
        let scored: [(Pocket, Int)] = catalog.pockets.compactMap { pocket in
            var words = wordTokens(pocket.baseName.lowercased())
            if words.last == "cc" { words.removeLast() }
            guard !words.isEmpty else { return nil }
            let hits = words.filter { tokens.contains($0) }
            guard hits.count == words.count else { return nil }
            let wantsCC = pocket.baseName.lowercased().split(separator: " ").map(String.init).contains("cc")
            if wantsCC && !tokens.contains("cc") && words.count < 2 { return nil }
            if wantsCC && words.count == 1 && !tokens.contains("cc") { return nil }
            return (pocket, hits.count + (wantsCC && tokens.contains("cc") ? 1 : 0))
        }
        var best = scored
        if let paidHint {
            let scoped = best.filter { pocketScope($0.0.scope) == paidHint }
            if !scoped.isEmpty { best = scoped }
        }
        guard let maxScore = best.map(\.1).max() else { return [] }
        let top = best.filter { $0.1 == maxScore }.map(\.0)
        return top.sorted { lhs, rhs in
            scopeRank(lhs.scope) < scopeRank(rhs.scope)
        }
    }

    private static func pocketScope(_ scope: Scope) -> PersonId? {
        switch scope {
        case .fern: return .fern
        case .stark: return .stark
        case .household, .business: return nil
        }
    }

    private static func scopeRank(_ scope: Scope) -> Int {
        switch scope {
        case .fern: return 0
        case .stark: return 1
        case .household: return 2
        case .business: return 3
        }
    }

    private static func ambiguityQuestion(pockets: [Pocket], catalog: Catalog) -> String {
        let shared = pockets.first?.baseName ?? "pocket"
        if pockets.allSatisfy({ $0.baseName == shared }), pockets.count == 2 {
            let a = personName(pockets[0].scope, catalog)
            let b = personName(pockets[1].scope, catalog)
            return "Which \(shared), \(a) or \(b)?"
        }
        let a = AccountLabels.display(baseName: pockets[0].baseName, scope: pockets[0].scope, personName: personName(pockets[0].scope, catalog))
        let b = AccountLabels.display(baseName: pockets[1].baseName, scope: pockets[1].scope, personName: personName(pockets[1].scope, catalog))
        return "Which card, \(a) or \(b)?"
    }

    private static func personName(_ scope: Scope, _ catalog: Catalog) -> String {
        switch scope {
        case .fern: return catalog.fernName
        case .stark: return catalog.starkName
        case .household, .business: return ""
        }
    }

    private static func resolveCategory(tokens: [String], extraKeywords: [String: String], catalog: Catalog) -> String? {
        for token in tokens {
            if let id = extraKeywords[token], catalog.categories.contains(where: { $0.id == id }) {
                return id
            }
        }
        let builtins: [String: (String, String)] = [
            "grocery": ("Groceries", "Household"),
            "groceries": ("Groceries", "Household"),
            "robinsons": ("Groceries", "Household"),
            "hotel": ("Travels", "Accommodation"),
            "meralco": ("Utilities", "Electricity"),
            "electricity": ("Utilities", "Electricity"),
            "rent": ("Rent", "House"),
        ]
        for token in tokens {
            if let pair = builtins[token],
               let cat = catalog.categories.first(where: { $0.group == pair.0 && $0.item == pair.1 }) {
                return cat.id
            }
        }
        return nil
    }

    private static func detectMerchant(in text: String) -> String? {
        let skip = Set([
            "Home", "Grocery", "Groceries", "Both", "Each", "Fern", "Stark", "Put", "In",
            "Cash", "GCash", "BPI", "BDO", "JCB", "CC", "MRT", "Debit",
        ])
        let regex = try? NSRegularExpression(pattern: "\\b[A-Z][A-Za-z]+\\b")
        let ns = text as NSString
        let matches = regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? []
        for match in matches {
            let word = ns.substring(with: match.range)
            if skip.contains(word) { continue }
            return word
        }
        return nil
    }

    private static func firstAmountC(in text: String) -> Int? {
        let regex = try? NSRegularExpression(pattern: "\\b(\\d+(?:\\.\\d{1,2})?)\\b")
        let ns = text as NSString
        guard let match = regex?.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        let raw = ns.substring(with: match.range(at: 1))
        return InputBounds.centavos(fromPesosText: raw)
    }

    private static func wordTokens(_ text: String) -> [String] {
        text.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { !$0.isEmpty }
    }
}

extension CaptureParse.Catalog {
    /// Starter CoA + pockets with stable ids for golden tests (mirrors `SeedCatalog` names).
    static func starters(fernName: String, starkName: String) -> CaptureParse.Catalog {
        CaptureParse.Catalog(
            pockets: [
                .init(id: "acct-house-cash", baseName: "House cash box", scope: .household, settlement: .instant, statementCutoff: nil),
                .init(id: "acct-bdo-jcb", baseName: "BDO JCB CC", scope: .household, settlement: .statement, statementCutoff: 15),
                .init(id: "acct-cash-fern", baseName: "Cash", scope: .fern, settlement: .instant, statementCutoff: nil),
                .init(id: "acct-bpi-debit", baseName: "BPI Debit", scope: .fern, settlement: .instant, statementCutoff: nil),
                .init(id: "acct-gcash-fern", baseName: "GCash", scope: .fern, settlement: .instant, statementCutoff: nil),
                .init(id: "acct-bpi-cc-fern", baseName: "BPI CC", scope: .fern, settlement: .statement, statementCutoff: 15),
                .init(id: "acct-cash-stark", baseName: "Cash", scope: .stark, settlement: .instant, statementCutoff: nil),
                .init(id: "acct-gcash-stark", baseName: "GCash", scope: .stark, settlement: .instant, statementCutoff: nil),
                .init(id: "acct-maya-stark", baseName: "Maya", scope: .stark, settlement: .instant, statementCutoff: nil),
            ],
            categories: [
                .init(id: "cat-rent-house", group: "Rent", item: "House", system: false),
                .init(id: "cat-utilities-electricity", group: "Utilities", item: "Electricity", system: false),
                .init(id: "cat-groceries-household", group: "Groceries", item: "Household", system: false),
                .init(id: "cat-travels-accommodation", group: "Travels", item: "Accommodation", system: false),
                .init(id: "cat-partner-contribution", group: "System", item: "Partner Contribution", system: true),
            ],
            fernName: fernName,
            starkName: starkName
        )
    }
}
