import Foundation

/// §4.6 Balance Day / Empire metrics — pure. UI never recomputes net worth.
enum Snapshot {
    enum LineSource: String, Codable, Sendable, Equatable {
        case derived
        case confirmed
        case stale
    }

    /// Propose how a Balance Day row behaves before confirm.
    enum Tier: String, Sendable, Equatable {
        case derived
        case prefilled
        case stale
    }

    enum Lens: String, Sendable, Equatable {
        case personal
        case household
    }

    struct Line: Equatable, Sendable, Codable {
        var accountId: String
        var balanceC: Int
        var source: LineSource
        var isLiability: Bool
        var countsTowardSavingsAssets: Bool
        /// Love Tab receivable / fund IOU — netted out on household lens.
        var isInternalDebt: Bool

        init(
            accountId: String,
            balanceC: Int,
            source: LineSource,
            isLiability: Bool,
            countsTowardSavingsAssets: Bool,
            isInternalDebt: Bool = false
        ) {
            self.accountId = accountId
            self.balanceC = balanceC
            self.source = source
            self.isLiability = isLiability
            self.countsTowardSavingsAssets = countsTowardSavingsAssets
            self.isInternalDebt = isInternalDebt
        }
    }

    typealias Metrics = PortfolioFern0820.Metrics

    static func defaultTier(kind: AccountKind) -> Tier {
        switch kind {
        case .investment, .savingsAsset, .govMandated:
            return .prefilled
        case .cash, .ewallet, .bank, .digitalBank, .creditCard, .receivable, .loan:
            return .derived
        }
    }

    static func isLiabilityKind(_ kind: AccountKind) -> Bool {
        switch kind {
        case .loan, .creditCard:
            return true
        case .cash, .ewallet, .bank, .digitalBank, .savingsAsset, .investment, .govMandated, .receivable:
            return false
        }
    }

    static func countsTowardSavingsAssets(kind: AccountKind) -> Bool {
        switch kind {
        case .savingsAsset, .govMandated:
            return true
        default:
            return false
        }
    }

    /// Confirmed + derived lines count; stale skipped. Household nets internal debts.
    static func metrics(lines: [Line], prior: Metrics?, lens: Lens) -> Metrics {
        let active = lines.filter { $0.source != .stale }
        let counted: [Line]
        switch lens {
        case .personal:
            counted = active
        case .household:
            counted = active.filter { !$0.isInternalDebt }
        }

        let assetsC = counted.filter { !$0.isLiability }.map(\.balanceC).reduce(0, +)
        let liabilitiesC = counted.filter(\.isLiability).map(\.balanceC).reduce(0, +)
        let netWorthC = assetsC - liabilitiesC
        let savingsAssetsC = counted.filter(\.countsTowardSavingsAssets).map(\.balanceC).reduce(0, +)

        let assetsDeltaC = prior.map { assetsC - $0.assetsC } ?? 0
        let liabilitiesDeltaC = prior.map { liabilitiesC - $0.liabilitiesC } ?? 0
        let netWorthDeltaC = prior.map { netWorthC - $0.netWorthC } ?? 0

        return Metrics(
            assetsC: assetsC,
            liabilitiesC: liabilitiesC,
            netWorthC: netWorthC,
            netWorthDeltaC: netWorthDeltaC,
            assetsDeltaC: assetsDeltaC,
            liabilitiesDeltaC: liabilitiesDeltaC,
            savingsAssetsC: savingsAssetsC
        )
    }
}
