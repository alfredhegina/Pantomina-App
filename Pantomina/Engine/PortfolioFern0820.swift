import Foundation

/// Spec §6 Phase 6 accept: Portfolio-Fern personal column for cycle anchor 2026-08-20.
/// Source: spreadsheet final NW table (SS3). Line inventory from the same sheet does not sum to these
/// totals (manual recording mess); do not invent bridging formulas. Balance Day will produce
/// consistent columns going forward.
public enum PortfolioFern0820 {
    public static let cycleAnchorISO = "2026-08-20"
    /// Stable person id (`fern` payer). Not `PersonId`: that type is app-internal.
    public static let personId = "fern"

    /// Seven Empire metrics (centavos). Sheet "Savings Rate" = pesos → `savingsAssetsC`.
    public struct Metrics: Equatable, Sendable {
        public var assetsC: Int
        public var liabilitiesC: Int
        public var netWorthC: Int
        public var netWorthDeltaC: Int
        public var assetsDeltaC: Int
        public var liabilitiesDeltaC: Int
        public var savingsAssetsC: Int

        public init(
            assetsC: Int,
            liabilitiesC: Int,
            netWorthC: Int,
            netWorthDeltaC: Int,
            assetsDeltaC: Int,
            liabilitiesDeltaC: Int,
            savingsAssetsC: Int
        ) {
            self.assetsC = assetsC
            self.liabilitiesC = liabilitiesC
            self.netWorthC = netWorthC
            self.netWorthDeltaC = netWorthDeltaC
            self.assetsDeltaC = assetsDeltaC
            self.liabilitiesDeltaC = liabilitiesDeltaC
            self.savingsAssetsC = savingsAssetsC
        }
    }

    public static let metrics = Metrics(
        assetsC: 57_349_347,
        liabilitiesC: 72_503_145,
        netWorthC: -15_153_798,
        netWorthDeltaC: 2_378_036,
        assetsDeltaC: 993_687,
        liabilitiesDeltaC: -1_384_349,
        savingsAssetsC: 10_003_633
    )
}
