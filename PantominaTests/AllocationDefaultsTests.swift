import Testing
@testable import Pantomina

@Suite("AllocationDefaults")
struct AllocationDefaultsTests {
    @Test("personal-scoped defaults to just mine for the payer")
    func personalJustMine() {
        let a = AllocationDefaults.forAmount(10_000, accountScope: .fern, paidBy: .fern)
        #expect(a.fern == 10_000)
        #expect(a.stark == 0)
    }

    @Test("household-scoped defaults to fifty-fifty")
    func householdSplit() {
        let a = AllocationDefaults.forAmount(10_000, accountScope: .household, paidBy: .fern)
        #expect(a.fern == 5_000)
        #expect(a.stark == 5_000)
    }

    @Test("odd centavo goes to fern on fifty-fifty")
    func oddSplit() {
        let a = AllocationDefaults.forAmount(10_001, accountScope: .household, paidBy: .fern)
        #expect(a.fern + a.stark == 10_001)
        #expect(a.fern == 5_001)
        #expect(a.stark == 5_000)
    }
}
