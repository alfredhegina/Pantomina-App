import Testing
@testable import Pantomina

@Suite("PortfolioFern0820")
struct PortfolioFern0820Tests {
    @Test("Spec Phase 6 accept: Fern 08/20 seven metrics and negative NW")
    func phase6AcceptMetrics() {
        let m = PortfolioFern0820.metrics
        #expect(PortfolioFern0820.cycleAnchorISO == "2026-08-20")
        #expect(PortfolioFern0820.personId == "fern")
        #expect(m.assetsC == 57_349_347)
        #expect(m.liabilitiesC == 72_503_145)
        #expect(m.netWorthC == -15_153_798)
        #expect(m.netWorthDeltaC == 2_378_036)
        #expect(m.assetsDeltaC == 993_687)
        #expect(m.liabilitiesDeltaC == -1_384_349)
        #expect(m.savingsAssetsC == 10_003_633)
    }

    @Test("metrics arithmetic is self-consistent")
    func arithmetic() {
        let m = PortfolioFern0820.metrics
        #expect(m.assetsC - m.liabilitiesC == m.netWorthC)
        #expect(m.assetsDeltaC - m.liabilitiesDeltaC == m.netWorthDeltaC)
        #expect(m.netWorthC < 0)
    }
}
