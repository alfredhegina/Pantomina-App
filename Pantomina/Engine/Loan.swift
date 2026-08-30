import Foundation

/// §4.11 loan register — pure. Balance is derived; UI never hand-types it.
enum Loan {
    enum Status: String, Equatable, Sendable, Codable {
        case active
        case done
    }

    enum Strategy: String, Equatable, Sendable, Codable {
        case prepay
        case parkToMaturity = "park_to_maturity"
    }

    struct JournalEntry: Equatable, Sendable, Codable {
        var dateISO: String
        var note: String
    }

    struct Snapshot: Equatable, Sendable {
        var id: String
        var lender: String
        var description: String
        var purpose: String
        var owner: PersonId
        var principalC: Int
        var totalLoanC: Int
        var termMonths: Int
        var paidMonths: Int
        var monthlyC: Int
        var cutoff: Int
        var startDateISO: String
        var endDateISO: String
        var aprPercent: Double
        var snowballOrder: Int?
        var snowballBatch: Int?
        var strategy: Strategy?
        var linkedReceivableAccountId: String?
        var journal: [JournalEntry]
        var status: Status
        var paymentAccountId: String
    }

    struct PaymentResult: Equatable, Sendable {
        var paidMonths: Int
        var balanceC: Int
        var status: Status
    }

    static func derivedBalanceC(totalLoanC: Int, paidMonths: Int, monthlyC: Int) -> Int {
        max(0, totalLoanC - paidMonths * monthlyC)
    }

    static func costOfBorrowingC(totalLoanC: Int, principalC: Int) -> Int {
        max(0, totalLoanC - principalC)
    }

    static func progressMonths(paid: Int, term: Int) -> (paid: Int, term: Int) {
        (paid: paid, term: term)
    }

    static func afterPayment(
        paidMonths: Int,
        termMonths: Int,
        totalLoanC: Int,
        monthlyC: Int
    ) -> PaymentResult {
        let next = min(termMonths, paidMonths + 1)
        let balance = derivedBalanceC(totalLoanC: totalLoanC, paidMonths: next, monthlyC: monthlyC)
        let status: Status = next >= termMonths ? .done : .active
        return PaymentResult(paidMonths: next, balanceC: balance, status: status)
    }

    /// Monthly loans land on the 15th or month-end cycle matching `cutoff` (15 or 30).
    static func isDue(cycleISO: String, cutoff: Int) -> Bool {
        let parts = cycleISO.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return false }
        let day = parts[2]
        if cutoff == 15 { return day == 15 }
        if cutoff == 30 { return day != 15 }
        return false
    }

    static func checklistTasks(
        cycleISO: String,
        loans: [Snapshot],
        doneIds: Set<String>
    ) -> [Checklist.Task] {
        let past = false
        return loans.compactMap { loan in
            guard loan.status == .active,
                  isDue(cycleISO: cycleISO, cutoff: loan.cutoff)
            else { return nil }
            let id = "loanpay-\(loan.id)-\(cycleISO)"
            let done = doneIds.contains(id)
            return Checklist.Task(
                id: id,
                cycleISO: cycleISO,
                title: loan.description,
                sourceAccountId: loan.paymentAccountId,
                amountC: loan.monthlyC,
                amountBehavior: .exact,
                kind: .loanPayment,
                paymentsRequired: 1,
                paymentsDone: done ? 1 : 0,
                linkedId: loan.id,
                done: done,
                pastCutoff: past && !done
            )
        }
    }

    static func appendJournal(dateISO: String, note: String, to journal: [JournalEntry]) -> [JournalEntry]? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return journal + [JournalEntry(dateISO: dateISO, note: trimmed)]
    }
}
