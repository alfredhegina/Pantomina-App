import Foundation
import SwiftData

@Model
final class PersonRecord {
    @Attribute(.unique) var personId: String
    var name: String
    var petName: String?
    var roleRaw: String
    var colorRaw: String

    init(id: PersonId, name: String, petName: String? = nil) {
        self.personId = id.rawValue
        self.name = name
        self.petName = petName
        self.roleRaw = id.role.rawValue
        self.colorRaw = id.colorToken.rawValue
    }

    var id: PersonId { PersonId(rawValue: personId) ?? .fern }
    var role: PersonRole { PersonRole(rawValue: roleRaw) ?? .payer }
    var color: PersonColor { PersonColor(rawValue: colorRaw) ?? .sage }
}

@Model
final class AccountRecord {
    @Attribute(.unique) var id: String
    var baseName: String
    var ownerRaw: String
    var scopeRaw: String
    var kindRaw: String
    var settlementRaw: String
    var statementCutoff: Int?
    var archived: Bool
    /// Last Balance Day confirmed balance (centavos). Prefill for next check-in.
    var lastConfirmedBalanceC: Int?
    var lastConfirmedCycleISO: String?

    init(
        id: String = UUID().uuidString,
        baseName: String,
        owner: String,
        scope: Scope,
        kind: AccountKind,
        settlement: SettlementKind,
        statementCutoff: Int? = nil,
        archived: Bool = false,
        lastConfirmedBalanceC: Int? = nil,
        lastConfirmedCycleISO: String? = nil
    ) {
        self.id = id
        self.baseName = baseName
        self.ownerRaw = owner
        self.scopeRaw = scope.rawValue
        self.kindRaw = kind.rawValue
        self.settlementRaw = settlement.rawValue
        self.statementCutoff = statementCutoff
        self.archived = archived
        self.lastConfirmedBalanceC = lastConfirmedBalanceC
        self.lastConfirmedCycleISO = lastConfirmedCycleISO
    }

    var scope: Scope { Scope(rawValue: scopeRaw) ?? .household }
    var kind: AccountKind { AccountKind(rawValue: kindRaw) ?? .cash }
    var settlement: SettlementKind { SettlementKind(rawValue: settlementRaw) ?? .instant }

    func displayLabel(fernName: String, starkName: String) -> String {
        let name: String
        switch scope {
        case .fern: name = fernName
        case .stark: name = starkName
        case .household, .business: name = ""
        }
        return AccountLabels.display(baseName: baseName, scope: scope, personName: name)
    }
}

@Model
final class CategoryRecord {
    @Attribute(.unique) var id: String
    var group: String
    var item: String
    var flowRaw: String
    var needWantRaw: String?
    var fixedVariableRaw: String?
    var system: Bool

    init(
        id: String = UUID().uuidString,
        group: String,
        item: String,
        flow: FlowType,
        needWant: NeedWant? = nil,
        fixedVariable: FixedVariable? = nil,
        system: Bool = false
    ) {
        self.id = id
        self.group = group
        self.item = item
        self.flowRaw = flow.rawValue
        self.needWantRaw = needWant?.rawValue
        self.fixedVariableRaw = fixedVariable?.rawValue
        self.system = system
    }

    var flow: FlowType { FlowType(rawValue: flowRaw) ?? .expense }
    var needWant: NeedWant? { needWantRaw.flatMap(NeedWant.init(rawValue:)) }
    var displayName: String { "\(group) · \(item)" }
}

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: String
    var purchaseDate: String
    var realizedDate: String?
    var realizedStatusRaw: String
    var proposedRealizedDate: String?
    var amountC: Int
    var accountId: String
    var categoryId: String
    var paidByRaw: String
    var allocFernC: Int
    var allocStarkC: Int
    var settlementRoleRaw: String?
    var linkedId: String?
    var recurringRuleId: String?
    var note: String?
    var merchant: String?
    /// When non-nil, transaction is a Cookie Jar entry (`income` / `spend` / `borrow`).
    var jarKindRaw: String?
    var jarSourceId: String?
    /// Borrows only: repaid yet?
    var jarReturned: Bool?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        purchaseDate: String,
        realizedDate: String? = nil,
        realizedStatus: RealizedStatus = .realized,
        proposedRealizedDate: String? = nil,
        amountC: Int,
        accountId: String,
        categoryId: String,
        paidBy: PersonId,
        allocation: Allocation,
        settlementRole: SettlementRole? = nil,
        linkedId: String? = nil,
        recurringRuleId: String? = nil,
        note: String? = nil,
        merchant: String? = nil,
        jarKind: CookieJar.Kind? = nil,
        jarSourceId: String? = nil,
        jarReturned: Bool? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.purchaseDate = purchaseDate
        self.realizedDate = realizedDate
        self.realizedStatusRaw = realizedStatus.rawValue
        self.proposedRealizedDate = proposedRealizedDate
        self.amountC = amountC
        self.accountId = accountId
        self.categoryId = categoryId
        self.paidByRaw = paidBy.rawValue
        self.allocFernC = allocation.fern
        self.allocStarkC = allocation.stark
        self.settlementRoleRaw = settlementRole?.rawValue
        self.linkedId = linkedId
        self.recurringRuleId = recurringRuleId
        self.note = note
        self.merchant = merchant
        self.jarKindRaw = jarKind?.rawValue
        self.jarSourceId = jarSourceId
        self.jarReturned = jarReturned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var paidBy: PersonId { PersonId(rawValue: paidByRaw) ?? .fern }
    var realizedStatus: RealizedStatus {
        get { RealizedStatus(rawValue: realizedStatusRaw) ?? .realized }
        set { realizedStatusRaw = newValue.rawValue }
    }
    var allocation: Allocation { Allocation(fern: allocFernC, stark: allocStarkC) }
    var settlementRole: SettlementRole? {
        get {
            guard let settlementRoleRaw else { return nil }
            return SettlementRole(rawValue: settlementRoleRaw)
        }
        set { settlementRoleRaw = newValue?.rawValue }
    }
    var jarKind: CookieJar.Kind? {
        get { jarKindRaw.flatMap(CookieJar.Kind.init(rawValue:)) }
        set { jarKindRaw = newValue?.rawValue }
    }
    var isJarEntry: Bool { jarKind != nil }

    func asJarEntry() -> CookieJar.Entry? {
        guard let kind = jarKind else { return nil }
        let date = realizedDate ?? purchaseDate
        return CookieJar.Entry(
            id: id,
            dateISO: date,
            amountC: amountC,
            kind: kind,
            sourceId: jarSourceId,
            returned: jarReturned,
            note: note
        )
    }
}

@Model
final class RecurringRuleRecord {
    @Attribute(.unique) var id: String
    var title: String
    var amountC: Int
    var accountId: String
    var categoryId: String
    var paidByRaw: String
    var allocFernC: Int
    var allocStarkC: Int
    var cadenceRaw: String
    var anchorDayRaw: String
    var amountBehaviorRaw: String
    var startCycleISO: String
    var endCycleISO: String?
    var paused: Bool
    var flowRaw: String
    var fixedVariableRaw: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        amountC: Int,
        accountId: String,
        categoryId: String,
        paidBy: PersonId,
        allocation: Allocation,
        cadence: Projection.Cadence,
        anchorDay: Projection.AnchorDay,
        amountBehavior: Projection.AmountBehavior,
        startCycleISO: String,
        endCycleISO: String? = nil,
        paused: Bool = false,
        flow: FlowType,
        fixedVariable: FixedVariable? = nil
    ) {
        self.id = id
        self.title = title
        self.amountC = amountC
        self.accountId = accountId
        self.categoryId = categoryId
        self.paidByRaw = paidBy.rawValue
        self.allocFernC = allocation.fern
        self.allocStarkC = allocation.stark
        self.cadenceRaw = cadence.rawValue
        self.anchorDayRaw = anchorDay.rawValue
        self.amountBehaviorRaw = amountBehavior.rawValue
        self.startCycleISO = startCycleISO
        self.endCycleISO = endCycleISO
        self.paused = paused
        self.flowRaw = flow.rawValue
        self.fixedVariableRaw = fixedVariable?.rawValue
    }

    var engineRule: Projection.Rule {
        Projection.Rule(
            id: id,
            amountC: amountC,
            accountId: accountId,
            categoryId: categoryId,
            paidBy: PersonId(rawValue: paidByRaw) ?? .fern,
            allocationFernC: allocFernC,
            allocationStarkC: allocStarkC,
            cadence: Projection.Cadence(rawValue: cadenceRaw) ?? .biweekly,
            anchorDay: Projection.AnchorDay(rawValue: anchorDayRaw) ?? .both,
            amountBehavior: Projection.AmountBehavior(rawValue: amountBehaviorRaw) ?? .exact,
            startCycleISO: startCycleISO,
            endCycleISO: endCycleISO,
            paused: paused,
            title: title,
            flow: FlowType(rawValue: flowRaw) ?? .expense,
            fixedVariable: fixedVariableRaw.flatMap(FixedVariable.init(rawValue:))
        )
    }
}

@Model
final class FundingPlanRecord {
    @Attribute(.unique) var id: String
    var billRecurringRuleId: String
    var billTitle: String
    var sourceAccountId: String
    var payoutCycleISO: String
    /// JSON array of `{cycleISO, amountC, reserved}`.
    var tranchesJSON: Data
    var paid: Bool

    init(
        id: String = UUID().uuidString,
        billRecurringRuleId: String,
        billTitle: String,
        sourceAccountId: String,
        payoutCycleISO: String,
        tranches: [Funding.Tranche],
        paid: Bool = false
    ) {
        self.id = id
        self.billRecurringRuleId = billRecurringRuleId
        self.billTitle = billTitle
        self.sourceAccountId = sourceAccountId
        self.payoutCycleISO = payoutCycleISO
        self.tranchesJSON = (try? JSONEncoder().encode(tranches)) ?? Data("[]".utf8)
        self.paid = paid
    }

    var enginePlan: Funding.Plan {
        let tranches = (try? JSONDecoder().decode([Funding.Tranche].self, from: tranchesJSON)) ?? []
        return Funding.Plan(
            id: id,
            billRecurringRuleId: billRecurringRuleId,
            billTitle: billTitle,
            sourceAccountId: sourceAccountId,
            payoutCycleISO: payoutCycleISO,
            tranches: tranches,
            paid: paid
        )
    }

    func apply(_ plan: Funding.Plan) {
        billRecurringRuleId = plan.billRecurringRuleId
        billTitle = plan.billTitle
        sourceAccountId = plan.sourceAccountId
        payoutCycleISO = plan.payoutCycleISO
        tranchesJSON = (try? JSONEncoder().encode(plan.tranches)) ?? tranchesJSON
        paid = plan.paid
    }
}

@Model
final class JarSourceRecord {
    @Attribute(.unique) var id: String
    var label: String
    var kindRaw: String
    /// JSON array of `{amountC, cadence}`.
    var expectedJSON: Data

    init(
        id: String = UUID().uuidString,
        label: String,
        kind: CookieJar.SourceKind,
        expected: [CookieJar.Expected] = []
    ) {
        self.id = id
        self.label = label
        self.kindRaw = kind.rawValue
        self.expectedJSON = (try? JSONEncoder().encode(expected)) ?? Data("[]".utf8)
    }

    var kind: CookieJar.SourceKind {
        CookieJar.SourceKind(rawValue: kindRaw) ?? .unit
    }

    var expected: [CookieJar.Expected] {
        (try? JSONDecoder().decode([CookieJar.Expected].self, from: expectedJSON)) ?? []
    }

    var engineSource: CookieJar.Source {
        CookieJar.Source(id: id, label: label, kind: kind, expected: expected)
    }
}

@Model
final class LoanRecord {
    @Attribute(.unique) var id: String
    var lender: String
    var loanDescription: String
    var purpose: String
    var ownerRaw: String
    var principalC: Int
    var totalLoanC: Int
    var termMonths: Int
    var paidMonths: Int
    var monthlyC: Int
    var cutoff: Int
    var startDateISO: String
    var endDateISO: String
    var aprPercent: Double
    var snowballOrder: Int?
    var snowballBatch: Int?
    var strategyRaw: String?
    var linkedReceivableAccountId: String?
    var journalJSON: Data
    var statusRaw: String
    var paymentAccountId: String

    init(
        id: String = UUID().uuidString,
        lender: String,
        description: String,
        purpose: String,
        owner: PersonId,
        principalC: Int,
        totalLoanC: Int,
        termMonths: Int,
        paidMonths: Int,
        monthlyC: Int,
        cutoff: Int,
        startDateISO: String,
        endDateISO: String,
        aprPercent: Double,
        snowballOrder: Int? = nil,
        snowballBatch: Int? = nil,
        strategy: Loan.Strategy? = nil,
        linkedReceivableAccountId: String? = nil,
        journal: [Loan.JournalEntry] = [],
        status: Loan.Status = .active,
        paymentAccountId: String
    ) {
        self.id = id
        self.lender = lender
        self.loanDescription = description
        self.purpose = purpose
        self.ownerRaw = owner.rawValue
        self.principalC = principalC
        self.totalLoanC = totalLoanC
        self.termMonths = termMonths
        self.paidMonths = paidMonths
        self.monthlyC = monthlyC
        self.cutoff = cutoff
        self.startDateISO = startDateISO
        self.endDateISO = endDateISO
        self.aprPercent = aprPercent
        self.snowballOrder = snowballOrder
        self.snowballBatch = snowballBatch
        self.strategyRaw = strategy?.rawValue
        self.linkedReceivableAccountId = linkedReceivableAccountId
        self.journalJSON = (try? JSONEncoder().encode(journal)) ?? Data("[]".utf8)
        self.statusRaw = status.rawValue
        self.paymentAccountId = paymentAccountId
    }

    var engineLoan: Loan.Snapshot {
        let journal = (try? JSONDecoder().decode([Loan.JournalEntry].self, from: journalJSON)) ?? []
        return Loan.Snapshot(
            id: id,
            lender: lender,
            description: loanDescription,
            purpose: purpose,
            owner: PersonId(rawValue: ownerRaw) ?? .fern,
            principalC: principalC,
            totalLoanC: totalLoanC,
            termMonths: termMonths,
            paidMonths: paidMonths,
            monthlyC: monthlyC,
            cutoff: cutoff,
            startDateISO: startDateISO,
            endDateISO: endDateISO,
            aprPercent: aprPercent,
            snowballOrder: snowballOrder,
            snowballBatch: snowballBatch,
            strategy: strategyRaw.flatMap(Loan.Strategy.init(rawValue:)),
            linkedReceivableAccountId: linkedReceivableAccountId,
            journal: journal,
            status: Loan.Status(rawValue: statusRaw) ?? .active,
            paymentAccountId: paymentAccountId
        )
    }

    var derivedBalanceC: Int {
        Loan.derivedBalanceC(totalLoanC: totalLoanC, paidMonths: paidMonths, monthlyC: monthlyC)
    }

    func applyPayment() {
        let result = Loan.afterPayment(
            paidMonths: paidMonths,
            termMonths: termMonths,
            totalLoanC: totalLoanC,
            monthlyC: monthlyC
        )
        paidMonths = result.paidMonths
        statusRaw = result.status.rawValue
    }

    func applySnowball(order: Int?, batch: Int?, strategy: Loan.Strategy?) {
        snowballOrder = order
        snowballBatch = batch
        strategyRaw = strategy?.rawValue
    }

    func appendJournal(dateISO: String, note: String) {
        let current = (try? JSONDecoder().decode([Loan.JournalEntry].self, from: journalJSON)) ?? []
        guard let next = Loan.appendJournal(dateISO: dateISO, note: note, to: current) else { return }
        journalJSON = (try? JSONEncoder().encode(next)) ?? journalJSON
    }
}

@Model
final class FundRecord {
    @Attribute(.unique) var id: String
    var name: String
    var purposeRaw: String
    var ownerRaw: String
    var homeAccountId: String
    var targetC: Int?
    var balanceC: Int
    var iousC: Int
    var iouLogJSON: Data
    var raidOrder: Int

    init(
        id: String = UUID().uuidString,
        name: String,
        purpose: Fund.Purpose,
        owner: PersonId = .fern,
        homeAccountId: String,
        targetC: Int? = nil,
        balanceC: Int,
        iousC: Int = 0,
        iouLog: [Fund.IOUEntry] = [],
        raidOrder: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.purposeRaw = purpose.rawValue
        self.ownerRaw = owner.rawValue
        self.homeAccountId = homeAccountId
        self.targetC = targetC
        self.balanceC = balanceC
        self.iousC = iousC
        self.iouLogJSON = (try? JSONEncoder().encode(iouLog)) ?? Data("[]".utf8)
        self.raidOrder = raidOrder ?? Fund.defaultRaidOrder(for: purpose)
    }

    var purpose: Fund.Purpose {
        Fund.Purpose(rawValue: purposeRaw) ?? .emergency
    }

    var engineFund: Fund.Snapshot {
        let log = (try? JSONDecoder().decode([Fund.IOUEntry].self, from: iouLogJSON)) ?? []
        return Fund.Snapshot(
            id: id,
            name: name,
            purpose: purpose,
            owner: PersonId(rawValue: ownerRaw) ?? .fern,
            homeAccountId: homeAccountId,
            targetC: targetC,
            balanceC: balanceC,
            iousC: iousC,
            iouLog: log,
            raidOrder: raidOrder
        )
    }

    func apply(_ snapshot: Fund.Snapshot) {
        name = snapshot.name
        purposeRaw = snapshot.purpose.rawValue
        ownerRaw = snapshot.owner.rawValue
        homeAccountId = snapshot.homeAccountId
        targetC = snapshot.targetC
        balanceC = snapshot.balanceC
        iousC = snapshot.iousC
        iouLogJSON = (try? JSONEncoder().encode(snapshot.iouLog)) ?? iouLogJSON
        raidOrder = snapshot.raidOrder
    }
}

@Model
final class SnapshotRecord {
    @Attribute(.unique) var id: String
    var cycleAnchorISO: String
    var personId: String
    var linesJSON: Data
    var assetsC: Int
    var liabilitiesC: Int
    var netWorthC: Int
    var netWorthDeltaC: Int
    var assetsDeltaC: Int
    var liabilitiesDeltaC: Int
    var savingsAssetsC: Int
    var confirmedAt: Date

    init(
        id: String = UUID().uuidString,
        cycleAnchorISO: String,
        personId: String,
        lines: [Snapshot.Line],
        metrics: Snapshot.Metrics,
        confirmedAt: Date = .now
    ) {
        self.id = id
        self.cycleAnchorISO = cycleAnchorISO
        self.personId = personId
        self.linesJSON = (try? JSONEncoder().encode(lines)) ?? Data("[]".utf8)
        self.assetsC = metrics.assetsC
        self.liabilitiesC = metrics.liabilitiesC
        self.netWorthC = metrics.netWorthC
        self.netWorthDeltaC = metrics.netWorthDeltaC
        self.assetsDeltaC = metrics.assetsDeltaC
        self.liabilitiesDeltaC = metrics.liabilitiesDeltaC
        self.savingsAssetsC = metrics.savingsAssetsC
        self.confirmedAt = confirmedAt
    }

    var lines: [Snapshot.Line] {
        (try? JSONDecoder().decode([Snapshot.Line].self, from: linesJSON)) ?? []
    }

    var metrics: Snapshot.Metrics {
        Snapshot.Metrics(
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

@Model
final class AppMeta {
    @Attribute(.unique) var key: String
    var onboardingComplete: Bool
    var fernIsPayer: Bool

    init(key: String = "main", onboardingComplete: Bool = false, fernIsPayer: Bool = true) {
        self.key = key
        self.onboardingComplete = onboardingComplete
        self.fernIsPayer = fernIsPayer
    }
}
