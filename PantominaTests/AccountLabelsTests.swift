import Testing
@testable import Pantomina

@Suite("AccountLabels")
struct AccountLabelsTests {
    @Test("household scope uses baseName only")
    func household() {
        let label = AccountLabels.display(baseName: "BDO JCB CC", scope: .household, personName: "Marco")
        #expect(label == "BDO JCB CC")
    }

    @Test("personal scope appends current person name at render time")
    func personal() {
        let label = AccountLabels.display(baseName: "BDO JCB CC", scope: .fern, personName: "Marco")
        #expect(label == "BDO JCB CC — Marco")
    }

    @Test("renaming person changes label without stored suffix")
    func rename() {
        let before = AccountLabels.display(baseName: "Cash", scope: .stark, personName: "Stark")
        let after = AccountLabels.display(baseName: "Cash", scope: .stark, personName: "Alex")
        #expect(before == "Cash — Stark")
        #expect(after == "Cash — Alex")
    }
}
