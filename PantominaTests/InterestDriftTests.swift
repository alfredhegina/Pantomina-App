import Foundation
import Testing
@testable import Pantomina

@Suite("InterestDrift")
struct InterestDriftTests {
    @Test("prompts only on unexplained positive rise")
    func positiveUnexplained() {
        let prompt = InterestDrift.prompt(
            homeAccountId: "bpi",
            previousConfirmedBalanceC: 10_000_00,
            currentBalanceC: 10_500_00,
            explainedIncomeC: 200_00
        )
        #expect(prompt?.unexplainedPositiveC == 300_00)

        #expect(
            InterestDrift.prompt(
                homeAccountId: "bpi",
                previousConfirmedBalanceC: 10_000_00,
                currentBalanceC: 10_200_00,
                explainedIncomeC: 200_00
            ) == nil
        )

        #expect(
            InterestDrift.prompt(
                homeAccountId: "bpi",
                previousConfirmedBalanceC: nil,
                currentBalanceC: 10_500_00,
                explainedIncomeC: 0
            ) == nil
        )
    }
}
