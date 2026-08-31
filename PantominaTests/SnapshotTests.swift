import Testing
@testable import Pantomina

@Suite("Snapshot")
struct SnapshotTests {
    private func asset(
        id: String,
        balanceC: Int,
        savings: Bool = false,
        internalDebt: Bool = false,
        source: Snapshot.LineSource = .confirmed
    ) -> Snapshot.Line {
        Snapshot.Line(
            accountId: id,
            balanceC: balanceC,
            source: source,
            isLiability: false,
            countsTowardSavingsAssets: savings,
            isInternalDebt: internalDebt
        )
    }

    private func liability(
        id: String,
        balanceC: Int,
        internalDebt: Bool = false,
        source: Snapshot.LineSource = .confirmed
    ) -> Snapshot.Line {
        Snapshot.Line(
            accountId: id,
            balanceC: balanceC,
            source: source,
            isLiability: true,
            countsTowardSavingsAssets: false,
            isInternalDebt: internalDebt
        )
    }

    @Test("personal lens sums assets and liabilities; skips stale")
    func personalMetrics() {
        let lines = [
            asset(id: "cash", balanceC: 10_000_00),
            asset(id: "mp2", balanceC: 5_000_00, savings: true),
            liability(id: "loan", balanceC: 8_000_00),
            asset(id: "skip", balanceC: 99_000_00, source: .stale),
        ]
        let m = Snapshot.metrics(lines: lines, prior: nil, lens: .personal)
        #expect(m.assetsC == 15_000_00)
        #expect(m.liabilitiesC == 8_000_00)
        #expect(m.netWorthC == 7_000_00)
        #expect(m.savingsAssetsC == 5_000_00)
        #expect(m.netWorthDeltaC == 0)
        #expect(m.assetsDeltaC == 0)
        #expect(m.liabilitiesDeltaC == 0)
    }

    @Test("deltas vs prior snapshot")
    func deltas() {
        let prior = Snapshot.Metrics(
            assetsC: 10_000_00,
            liabilitiesC: 5_000_00,
            netWorthC: 5_000_00,
            netWorthDeltaC: 0,
            assetsDeltaC: 0,
            liabilitiesDeltaC: 0,
            savingsAssetsC: 0
        )
        let lines = [
            asset(id: "a", balanceC: 12_000_00),
            liability(id: "l", balanceC: 4_000_00),
        ]
        let m = Snapshot.metrics(lines: lines, prior: prior, lens: .personal)
        #expect(m.assetsDeltaC == 2_000_00)
        #expect(m.liabilitiesDeltaC == -1_000_00)
        #expect(m.netWorthDeltaC == 3_000_00)
    }

    @Test("household lens nets internal debts to zero")
    func householdNetsInternal() {
        let lines = [
            asset(id: "cash", balanceC: 50_000_00),
            asset(id: "loveTab", balanceC: 177_697_81, internalDebt: true),
            liability(id: "loan", balanceC: 100_000_00),
            liability(id: "fundIOU", balanceC: 6_500_00, internalDebt: true),
        ]
        let personal = Snapshot.metrics(lines: lines, prior: nil, lens: .personal)
        #expect(personal.assetsC == 50_000_00 + 177_697_81)
        #expect(personal.liabilitiesC == 100_000_00 + 6_500_00)

        let household = Snapshot.metrics(lines: lines, prior: nil, lens: .household)
        #expect(household.assetsC == 50_000_00)
        #expect(household.liabilitiesC == 100_000_00)
        #expect(household.netWorthC == -50_000_00)
    }

    @Test("negative net worth is allowed")
    func negativeNW() {
        let lines = [
            asset(id: "a", balanceC: 1_000_00),
            liability(id: "l", balanceC: 10_000_00),
        ]
        let m = Snapshot.metrics(lines: lines, prior: nil, lens: .personal)
        #expect(m.netWorthC == -9_000_00)
    }

    @Test("Portfolio-Fern 08/20 golden remains the Spec accept constant")
    func fernGoldenUnchanged() {
        #expect(PortfolioFern0820.metrics.netWorthC == -15_153_798)
    }

    @Test("default tier: investments prefilled; loans derived")
    func defaultTiers() {
        #expect(Snapshot.defaultTier(kind: .investment) == .prefilled)
        #expect(Snapshot.defaultTier(kind: .savingsAsset) == .prefilled)
        #expect(Snapshot.defaultTier(kind: .govMandated) == .prefilled)
        #expect(Snapshot.defaultTier(kind: .loan) == .derived)
        #expect(Snapshot.defaultTier(kind: .cash) == .derived)
        #expect(Snapshot.defaultTier(kind: .receivable) == .derived)
    }

    @Test("kind helpers for liability and savings")
    func kindHelpers() {
        #expect(Snapshot.isLiabilityKind(.loan))
        #expect(Snapshot.isLiabilityKind(.creditCard))
        #expect(!Snapshot.isLiabilityKind(.bank))
        #expect(Snapshot.countsTowardSavingsAssets(kind: .savingsAsset))
        #expect(Snapshot.countsTowardSavingsAssets(kind: .govMandated))
        #expect(!Snapshot.countsTowardSavingsAssets(kind: .investment))
    }
}
