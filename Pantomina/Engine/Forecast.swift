import Foundation

/// §4.5 cycle forecast — pure math. UI never reimplements.
enum Forecast {
    enum Reason: String, Sendable {
        case income
        case fixed
        case estimate
        case cardLandsHere
        case tranche
    }

    enum Verdict: String, Sendable {
        case breathingRoom
        case over
        case tight
    }

    struct Line: Equatable, Sendable {
        var id: String
        var title: String
        var amountC: Int
        var reason: Reason
    }

    struct IncomeRow: Equatable, Sendable {
        var id: String
        var title: String
        var amountC: Int
    }

    struct PendingCard: Equatable, Sendable {
        var id: String
        var title: String
        var amountC: Int
    }

    struct Result: Equatable, Sendable {
        var expectedIn: [Line]
        var committed: [Line]
        var expectedInC: Int
        var committedC: Int
        var typicalVariableC: Int
        /// Positive = breathing room; negative = over by abs.
        var breathingRoomC: Int
        var verdict: Verdict
    }

    static func compute(
        expectedIn: [Line],
        committed: [Line],
        typicalVariableC: Int
    ) -> Result {
        let inC = expectedIn.reduce(0) { $0 + $1.amountC }
        let comC = committed.reduce(0) { $0 + $1.amountC }
        let room = inC - comC - max(0, typicalVariableC)
        let verdict: Verdict
        if room > 0 {
            verdict = .breathingRoom
        } else if room < 0 {
            verdict = .over
        } else {
            verdict = .tight
        }
        return Result(
            expectedIn: expectedIn,
            committed: committed,
            expectedInC: inC,
            committedC: comC,
            typicalVariableC: typicalVariableC,
            breathingRoomC: room,
            verdict: verdict
        )
    }

    /// Assemble forecast lines. Does not invent contribution. Tranches empty until Slice B.
    static func build(
        cycleISO: String,
        incomeRows: [IncomeRow],
        projected: [Projection.DraftRow],
        pendingCards: [PendingCard],
        trancheLines: [Line],
        typicalVariableC: Int
    ) -> Result {
        _ = cycleISO
        let expectedIn = incomeRows.map {
            Line(id: $0.id, title: $0.title, amountC: $0.amountC, reason: .income)
        }
        var committed: [Line] = []
        for row in projected where row.flow == .expense {
            let reason: Reason = row.amountBehavior == .estimate ? .estimate : .fixed
            committed.append(
                Line(id: row.id, title: row.title, amountC: row.amountC, reason: reason)
            )
        }
        for card in pendingCards {
            committed.append(
                Line(id: card.id, title: card.title, amountC: card.amountC, reason: .cardLandsHere)
            )
        }
        committed.append(contentsOf: trancheLines)
        return compute(
            expectedIn: expectedIn,
            committed: committed,
            typicalVariableC: typicalVariableC
        )
    }
}
