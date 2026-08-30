import Testing
@testable import Pantomina

@Suite("Checklist")
struct ChecklistTests {
    private let rentRule = Projection.Rule(
        id: "rule-rent",
        amountC: 20_000_00,
        accountId: "acct-cash",
        categoryId: "cat-rent",
        paidBy: .fern,
        allocationFernC: 10_000_00,
        allocationStarkC: 10_000_00,
        cadence: .biweekly,
        anchorDay: .both,
        amountBehavior: .exact,
        startCycleISO: "2026-08-15",
        endCycleISO: nil,
        paused: false,
        title: "Rent · House",
        flow: .expense,
        fixedVariable: .fixed
    )

    @Test("builds bill tasks from rules and cc_statement when pending exists")
    func buildsTasks() {
        let tasks = Checklist.tasks(
            cycleISO: "2026-09-15",
            todayISO: "2026-09-10",
            rules: [rentRule],
            statementAccountsWithPending: ["acct-bdo"],
            trancheTasks: [],
            doneIds: []
        )
        #expect(tasks.contains { $0.kind == .bill && $0.linkedId == "rule-rent" })
        #expect(tasks.contains { $0.kind == .ccStatement && $0.sourceAccountId == "acct-bdo" })
        let summary = Checklist.summary(tasks: tasks)
        #expect(summary.totalCount == tasks.count)
        #expect(summary.doneCount == 0)
        #expect(summary.stillToSendC == tasks.filter { $0.kind != .ccStatement }.reduce(0) { $0 + $1.amountC })
    }

    @Test("tick marks done and past-cutoff flags late tasks")
    func tickAndCutoff() {
        var tasks = Checklist.tasks(
            cycleISO: "2026-09-15",
            todayISO: "2026-09-20",
            rules: [rentRule],
            statementAccountsWithPending: [],
            trancheTasks: [],
            doneIds: []
        )
        #expect(tasks[0].pastCutoff == true)
        let id = tasks[0].id
        tasks = Checklist.tick(taskId: id, in: tasks)
        #expect(tasks.first { $0.id == id }?.done == true)
        let summary = Checklist.summary(tasks: tasks)
        #expect(summary.doneCount == 1)
        #expect(summary.stillToSendC == 0)
    }

    @Test("includes loan_payment tasks from Loan snapshots")
    func includesLoanPayments() {
        let loan = Loan.Snapshot(
            id: "loan-ub",
            lender: "UB",
            description: "UB Personal",
            purpose: "Consolidate",
            owner: .fern,
            principalC: 850_000_00,
            totalLoanC: 104_819_460,
            termMonths: 60,
            paidMonths: 24,
            monthlyC: 17_469_91,
            cutoff: 15,
            startDateISO: "2024-08-15",
            endDateISO: "2029-08-15",
            aprPercent: 18.5,
            snowballOrder: 1,
            snowballBatch: 1,
            strategy: nil,
            linkedReceivableAccountId: nil,
            journal: [],
            status: .active,
            paymentAccountId: "acct-bpi"
        )
        let tasks = Checklist.tasks(
            cycleISO: "2026-08-15",
            todayISO: "2026-08-10",
            rules: [],
            statementAccountsWithPending: [],
            trancheTasks: [],
            loanSnapshots: [loan],
            doneIds: []
        )
        #expect(tasks.contains { $0.kind == .loanPayment && $0.linkedId == "loan-ub" })
        #expect(tasks.first { $0.kind == .loanPayment }?.amountC == 17_469_91)
    }
}
