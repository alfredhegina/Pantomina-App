import Foundation

/// §4.10 funds, raids & IOUs: pure. UI never reimplements owed / effective / repay order.
enum Fund {
    enum Purpose: String, Equatable, Sendable, Codable {
        case emergency
        case sinking
        case loanPayoff = "loan_payoff"
        case goal
    }

    /// Per-raid choice: personal fund covers shared (default) vs inflate contributor due.
    enum Attribution: String, Equatable, Sendable, Codable {
        case absorb
        case addToDue = "add_to_due"
    }

    struct IOUEntry: Equatable, Sendable, Codable, Identifiable {
        var id: String
        var dateISO: String
        var amountC: Int
        var reason: String
        var repaidC: Int
        var attribution: Attribution

        var outstandingC: Int { max(0, amountC - repaidC) }
        var isOpen: Bool { outstandingC > 0 }
    }

    struct Snapshot: Equatable, Sendable {
        var id: String
        var name: String
        var purpose: Purpose
        var owner: PersonId
        var homeAccountId: String
        var targetC: Int?
        var balanceC: Int
        var iousC: Int
        var iouLog: [IOUEntry]
        /// Lower = earlier in raid order (loan_payoff=1, sinking=2, emergency=3, goal=4).
        var raidOrder: Int
    }

    static func owedBackC(_ fund: Snapshot) -> Int {
        max(0, fund.iousC)
    }

    /// Cash still in the envelope for further raids. Raid already dips `balanceC`; do not subtract IOUs again.
    static func effectiveBalanceC(_ fund: Snapshot) -> Int {
        max(0, fund.balanceC)
    }

    /// Note marker for opening Fund Moves (Receipts cascade delete).
    static let openingNoteMarker = "· opening"

    static func raidCandidates(from funds: [Snapshot]) -> [Snapshot] {
        funds
            .filter { $0.balanceC > 0 }
            .sorted {
                if $0.raidOrder != $1.raidOrder { return $0.raidOrder < $1.raidOrder }
                return $0.name < $1.name
            }
    }

    static func defaultRaidOrder(for purpose: Purpose) -> Int {
        switch purpose {
        case .loanPayoff: return 1
        case .sinking: return 2
        case .emergency: return 3
        case .goal: return 4
        }
    }

    /// Credit the envelope (opening or top-up). Returns nil if amount ≤ 0.
    static func topUp(to fund: Snapshot, amountC: Int) -> Snapshot? {
        guard amountC > 0 else { return nil }
        var next = fund
        next.balanceC += amountC
        return next
    }

    /// Fern personal cash / bank / e-wallet / digital bank: spend pockets for raid destination.
    static func isSpendPocket(kind: AccountKind, scope: Scope) -> Bool {
        guard scope == .fern else { return false }
        switch kind {
        case .cash, .bank, .ewallet, .digitalBank: return true
        case .creditCard, .savingsAsset, .investment, .govMandated, .receivable, .loan: return false
        }
    }

    /// Pull from fund for bills. Returns nil if amount invalid or exceeds balance.
    static func applyRaid(
        to fund: Snapshot,
        amountC: Int,
        dateISO: String,
        reason: String,
        attribution: Attribution
    ) -> Snapshot? {
        guard amountC > 0, amountC <= fund.balanceC else { return nil }
        var next = fund
        next.balanceC -= amountC
        next.iousC += amountC
        next.iouLog.append(
            IOUEntry(
                id: UUID().uuidString,
                dateISO: dateISO,
                amountC: amountC,
                reason: reason,
                repaidC: 0,
                attribution: attribution
            )
        )
        return next
    }

    /// Apply repayment to oldest open IOU first. Optionally restore `balanceC` (money returned to fund).
    static func repayOldest(in fund: Snapshot, amountC: Int, restoreBalance: Bool) -> Snapshot? {
        guard amountC > 0, fund.iousC > 0 else { return nil }
        var next = fund
        var remaining = amountC
        var log = next.iouLog
        for i in log.indices where log[i].isOpen && remaining > 0 {
            let pay = min(remaining, log[i].outstandingC)
            log[i].repaidC += pay
            remaining -= pay
            next.iousC -= pay
            if restoreBalance { next.balanceC += pay }
        }
        guard remaining < amountC else { return nil }
        next.iouLog = log
        next.iousC = max(0, next.iousC)
        return next
    }

    /// Rough "whole again" date: ceil(ious / monthly) half-month steps from `fromISO` cycle.
    static func wholeAgainAtISO(fund: Snapshot, monthlyRepayC: Int, fromISO: String) -> String? {
        guard fund.iousC > 0, monthlyRepayC > 0 else { return nil }
        let months = (fund.iousC + monthlyRepayC - 1) / monthlyRepayC
        var cycle = Cycle(anchorISO: fromISO)
        for _ in 0..<months {
            // Two half-months ≈ one calendar month of repay cadence.
            cycle = Cycle.nextHalfMonth(after: cycle)
            cycle = Cycle.nextHalfMonth(after: cycle)
        }
        return cycle.anchorISO
    }
}
