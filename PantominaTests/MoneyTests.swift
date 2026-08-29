import Testing
@testable import Pantomina

@Suite("Money")
struct MoneyTests {
    @Test("formats centavos with two decimals and peso sign")
    func twoDecimals() {
        #expect(formatPeso(1_281_334) == "₱12,813.34")
        #expect(formatPeso(0) == "₱0.00")
        #expect(formatPeso(50) == "₱0.50")
    }

    @Test("dashboard style rounds to whole pesos")
    func wholePesos() {
        #expect(formatPeso(1_281_334, fractionDigits: 0) == "₱12,813")
        #expect(formatPeso(3_783_700, fractionDigits: 0) == "₱37,837")
    }
}
