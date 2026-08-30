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

    init(
        id: String = UUID().uuidString,
        baseName: String,
        owner: String,
        scope: Scope,
        kind: AccountKind,
        settlement: SettlementKind,
        statementCutoff: Int? = nil,
        archived: Bool = false
    ) {
        self.id = id
        self.baseName = baseName
        self.ownerRaw = owner
        self.scopeRaw = scope.rawValue
        self.kindRaw = kind.rawValue
        self.settlementRaw = settlement.rawValue
        self.statementCutoff = statementCutoff
        self.archived = archived
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
