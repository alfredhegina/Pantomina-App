import Foundation

/// Interest drift on a fund home pocket: pure. UI must confirm before booking.
enum InterestDrift {
    struct Prompt: Equatable, Sendable, Identifiable {
        var id: String { homeAccountId }
        var homeAccountId: String
        var unexplainedPositiveC: Int
    }

    /// When pocket truth rose more than explained ledger income on that pocket since last confirm.
    /// `explainedIncomeC` = sum of realized income-classified legs after `lastConfirmedAt` (caller).
    /// Returns a prompt only for strictly positive unexplained drift.
    static func prompt(
        homeAccountId: String,
        previousConfirmedBalanceC: Int?,
        currentBalanceC: Int,
        explainedIncomeC: Int
    ) -> Prompt? {
        guard let previous = previousConfirmedBalanceC else { return nil }
        let delta = currentBalanceC - previous
        guard delta > 0 else { return nil }
        let unexplained = delta - max(0, explainedIncomeC)
        guard unexplained > 0 else { return nil }
        return Prompt(homeAccountId: homeAccountId, unexplainedPositiveC: unexplained)
    }
}
