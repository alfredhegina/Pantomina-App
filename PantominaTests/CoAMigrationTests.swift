import Testing
@testable import Pantomina

@Suite("CoAMigration")
struct CoAMigrationTests {
    @Test("typo Subcription maps to Subscription")
    func subscriptionTypo() {
        let m = CoAMigration.map(legacy: "Subcription · Netflix")
        #expect(m?.group == "Subscription")
        #expect(m?.item == "Netflix")
        #expect(m?.oddity == nil)
    }

    @Test("typo Accomodation maps to Accommodation")
    func accommodationTypo() {
        let m = CoAMigration.map(legacy: "Travels · Accomodation")
        #expect(m?.group == "Travels")
        #expect(m?.item == "Accommodation")
    }

    @Test("Loan group surfaces Want oddity")
    func loanWantOddity() {
        let m = CoAMigration.map(legacy: "Loan · BPI Credit to Cash")
        #expect(m?.needWant == .want)
        #expect(m?.oddity == .loanMarkedWant)
    }

    @Test("Child Support Birthday is Want oddity; Siblings Birthday is Need")
    func birthdayOddities() {
        let child = CoAMigration.map(legacy: "Child Support · Birthday")
        #expect(child?.needWant == .want)
        #expect(child?.oddity == .childSupportBirthdayWant)

        let sib = CoAMigration.map(legacy: "Siblings · Birthday")
        #expect(sib?.needWant == .need)
        #expect(sib?.oddity == nil)
    }

    @Test("Smart Postpaid is the Want utility oddity")
    func smartPostpaid() {
        let m = CoAMigration.map(legacy: "Utilities · Smart Postpaid")
        #expect(m?.needWant == .want)
        #expect(m?.oddity == .smartPostpaidWant)
    }

    @Test("legacy person-suffixed salary strips name into scope")
    func salaryScope() {
        let fern = CoAMigration.map(legacy: "Salary · Larr")
        #expect(fern?.group == "Income")
        #expect(fern?.item == "Salary")
        #expect(fern?.scopeHint == .fern)

        let stark = CoAMigration.map(legacy: "Salary · Len")
        #expect(stark?.scopeHint == .stark)
    }
}
