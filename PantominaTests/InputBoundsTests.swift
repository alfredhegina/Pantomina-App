import Testing
@testable import Pantomina

@Suite("InputBounds")
struct InputBoundsTests {
    @Test("clamps display name to 40 graphemes")
    func displayNameClamp() {
        let long = String(repeating: "a", count: 50)
        #expect(InputBounds.clampDisplayName(long).count == 40)
        #expect(InputBounds.clampDisplayName("  Fern  ") == "Fern")
    }

    @Test("clamps pet name to 24 graphemes")
    func petNameClamp() {
        let long = String(repeating: "b", count: 30)
        #expect(InputBounds.clampPetName(long).count == 24)
    }

    @Test("clamps note to 200 graphemes")
    func noteClamp() {
        let long = String(repeating: "n", count: 250)
        #expect(InputBounds.clampNote(long).count == 200)
    }

    @Test("accepts amounts from 1 centavo through 100M pesos")
    func amountRange() {
        #expect(InputBounds.isValidAmountC(1))
        #expect(InputBounds.isValidAmountC(InputBounds.maxAmountC))
        #expect(!InputBounds.isValidAmountC(0))
        #expect(!InputBounds.isValidAmountC(InputBounds.maxAmountC + 1))
        #expect(!InputBounds.isValidAmountC(-1))
    }

    @Test("maxAmountC is 100_000_000 pesos in centavos")
    func maxCentavos() {
        #expect(InputBounds.maxAmountC == 10_000_000_000)
        #expect(InputBounds.maxAmountPesos == 100_000_000)
    }

    @Test("parses peso text into centavos within bounds")
    func parsePesos() {
        #expect(InputBounds.centavos(fromPesosText: "12.34") == 1_234)
        #expect(InputBounds.centavos(fromPesosText: "100000000") == InputBounds.maxAmountC)
        #expect(InputBounds.centavos(fromPesosText: "100000000.01") == nil)
        #expect(InputBounds.centavos(fromPesosText: "0") == nil)
        #expect(InputBounds.centavos(fromPesosText: "abc") == nil)
    }
}
