import Testing
@testable import Pantomina

@Suite("Loan")
struct LoanTests {
    /// Spec §6 Phase 5 accept: 24/60 paid → ₱628,916.76.
    /// monthly = ₱17,469.91 so remaining 36 × monthly = balance exactly.
    private let ubMonthlyC = 17_469_91
    private let ubTotalLoanC = 104_819_460 // 24×monthly + 628_916_76
    private let ubPrincipalC = 850_000_00

    private func ubPersonal(paidMonths: Int = 24) -> Loan.Snapshot {
        Loan.Snapshot(
            id: "loan-ub-personal",
            lender: "UnionBank",
            description: "UB Personal Loan",
            purpose: "Debt consolidation",
            owner: .fern,
            principalC: ubPrincipalC,
            totalLoanC: ubTotalLoanC,
            termMonths: 60,
            paidMonths: paidMonths,
            monthlyC: ubMonthlyC,
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
            paymentAccountId: "acct-bpi-debit"
        )
    }

    @Test("UB Personal 24/60 → balance ₱628,916.76 exactly")
    func ubPersonalAcceptFixture() {
        let loan = ubPersonal()
        #expect(Loan.derivedBalanceC(totalLoanC: loan.totalLoanC, paidMonths: loan.paidMonths, monthlyC: loan.monthlyC) == 628_916_76)
        #expect(Loan.progressMonths(paid: 24, term: 60) == (paid: 24, term: 60))
        #expect(Loan.costOfBorrowingC(totalLoanC: ubTotalLoanC, principalC: ubPrincipalC) == ubTotalLoanC - ubPrincipalC)
    }

    @Test("afterPayment bumps paidMonths and derived balance; done at term")
    func afterPayment() {
        let mid = Loan.afterPayment(
            paidMonths: 24,
            termMonths: 60,
            totalLoanC: ubTotalLoanC,
            monthlyC: ubMonthlyC
        )
        #expect(mid.paidMonths == 25)
        #expect(mid.balanceC == Loan.derivedBalanceC(totalLoanC: ubTotalLoanC, paidMonths: 25, monthlyC: ubMonthlyC))
        #expect(mid.status == .active)

        let last = Loan.afterPayment(
            paidMonths: 59,
            termMonths: 60,
            totalLoanC: ubTotalLoanC,
            monthlyC: ubMonthlyC
        )
        #expect(last.paidMonths == 60)
        #expect(last.balanceC == 0)
        #expect(last.status == .done)
    }

    @Test("loan due on cutoff-matching cycle only")
    func dueOnCutoffCycle() {
        let loan = ubPersonal()
        #expect(Loan.isDue(cycleISO: "2026-08-15", cutoff: loan.cutoff))
        #expect(!Loan.isDue(cycleISO: "2026-08-31", cutoff: loan.cutoff))
        #expect(Loan.isDue(cycleISO: "2026-08-31", cutoff: 30))
    }

    @Test("checklist payment task for active due loan")
    func checklistTask() {
        let tasks = Loan.checklistTasks(
            cycleISO: "2026-08-15",
            loans: [ubPersonal()],
            doneIds: []
        )
        #expect(tasks.count == 1)
        #expect(tasks[0].kind == .loanPayment)
        #expect(tasks[0].amountC == ubMonthlyC)
        #expect(tasks[0].linkedId == "loan-ub-personal")
        #expect(!tasks[0].done)

        let none = Loan.checklistTasks(
            cycleISO: "2026-08-31",
            loans: [ubPersonal()],
            doneIds: []
        )
        #expect(none.isEmpty)

        let done = Loan.checklistTasks(
            cycleISO: "2026-08-15",
            loans: [ubPersonal()],
            doneIds: ["loanpay-loan-ub-personal-2026-08-15"]
        )
        #expect(done[0].done)
    }
}
