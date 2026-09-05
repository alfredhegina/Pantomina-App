import Foundation

/// Rules for creating and editing pockets and user categories. UI never reimplements these.
enum LedgerCatalog {
    static let userScopes: [Scope] = [.household, .fern, .stark]
    static let userFlows: [FlowType] = [.expense, .income, .savings, .sinking]
    static let userKinds: [AccountKind] = [
        .cash, .bank, .ewallet, .digitalBank, .creditCard, .savingsAsset, .investment, .govMandated,
    ]

    struct ExistingPocket: Equatable, Sendable {
        var id: String
        var baseName: String
        var scope: Scope
    }

    struct ExistingCategory: Equatable, Sendable {
        var id: String
        var group: String
        var item: String
        var system: Bool
    }

    struct PocketShape: Equatable, Sendable {
        var scope: Scope
        var kind: AccountKind
        var statementCutoff: Int?
    }

    struct CategoryTags: Equatable, Sendable {
        var flow: FlowType
        var needWant: NeedWant?
        var fixedVariable: FixedVariable?
    }

    struct PocketInput: Equatable, Sendable {
        var baseName: String
        var scope: Scope
        var kind: AccountKind
        var statementCutoff: Int?
        var existingId: String?
        var lockedShape: PocketShape?
    }

    struct PocketDraft: Equatable, Sendable {
        var baseName: String
        var scope: Scope
        var kind: AccountKind
        var settlement: SettlementKind
        var statementCutoff: Int?
        var owner: String
    }

    struct CategoryInput: Equatable, Sendable {
        var group: String
        var item: String
        var flow: FlowType
        var needWant: NeedWant?
        var fixedVariable: FixedVariable?
        var existingId: String?
        var lockedTags: CategoryTags?
        var system: Bool
    }

    struct CategoryDraft: Equatable, Sendable {
        var group: String
        var item: String
        var flow: FlowType
        var needWant: NeedWant?
        var fixedVariable: FixedVariable?
    }

    enum PocketIssue: Equatable, Sendable, Error {
        case emptyName
        case duplicate
        case shapeLocked
        case cutoffNeeded
        case businessNotAllowed
        case kindNotAllowed
    }

    enum CategoryIssue: Equatable, Sendable, Error {
        case emptyGroup
        case emptyItem
        case duplicate
        case tagsLocked
        case needWantNeeded
        case fixedVariableNeeded
        case transferNotAllowed
        case systemNotAllowed
    }

    static func owner(for scope: Scope) -> String {
        switch scope {
        case .household, .business: return "household"
        case .fern: return PersonId.fern.rawValue
        case .stark: return PersonId.stark.rawValue
        }
    }

    static func settlement(for kind: AccountKind, cutoff: Int?) -> (SettlementKind, Int?) {
        if kind == .creditCard {
            return (.statement, cutoff)
        }
        return (.instant, nil)
    }

    static func pocketInUse(
        id: String,
        transactionAccountIds: Set<String>,
        ruleAccountIds: Set<String>,
        fundHomeAccountIds: Set<String> = [],
        loanPaymentAccountIds: Set<String> = [],
        fundingSourceAccountIds: Set<String> = []
    ) -> Bool {
        transactionAccountIds.contains(id)
            || ruleAccountIds.contains(id)
            || fundHomeAccountIds.contains(id)
            || loanPaymentAccountIds.contains(id)
            || fundingSourceAccountIds.contains(id)
    }

    static func categoryInUse(id: String, transactionCategoryIds: Set<String>, ruleCategoryIds: Set<String>) -> Bool {
        transactionCategoryIds.contains(id) || ruleCategoryIds.contains(id)
    }

    static func validatePocket(_ input: PocketInput, existing: [ExistingPocket]) -> Result<PocketDraft, PocketIssue> {
        if input.scope == .business { return .failure(.businessNotAllowed) }
        if !userKinds.contains(input.kind) { return .failure(.kindNotAllowed) }
        let name = InputBounds.clampDisplayName(input.baseName)
        guard !name.isEmpty else { return .failure(.emptyName) }

        if let locked = input.lockedShape {
            let cutoff = input.kind == .creditCard ? input.statementCutoff : nil
            if input.scope != locked.scope || input.kind != locked.kind || cutoff != locked.statementCutoff {
                return .failure(.shapeLocked)
            }
        }

        let (settlement, cutoff) = settlement(for: input.kind, cutoff: input.statementCutoff)
        if input.kind == .creditCard {
            guard cutoff == 15 || cutoff == 30 else { return .failure(.cutoffNeeded) }
        }

        let duplicate = existing.contains { other in
            other.id != input.existingId
                && other.scope == input.scope
                && other.baseName.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if duplicate { return .failure(.duplicate) }

        return .success(
            PocketDraft(
                baseName: name,
                scope: input.scope,
                kind: input.kind,
                settlement: settlement,
                statementCutoff: cutoff,
                owner: owner(for: input.scope)
            )
        )
    }

    static func validateCategory(_ input: CategoryInput, existing: [ExistingCategory]) -> Result<CategoryDraft, CategoryIssue> {
        if input.system { return .failure(.systemNotAllowed) }
        if input.flow == .transfer { return .failure(.transferNotAllowed) }

        let group = InputBounds.clampDisplayName(input.group)
        let item = InputBounds.clampDisplayName(input.item)
        guard !group.isEmpty else { return .failure(.emptyGroup) }
        guard !item.isEmpty else { return .failure(.emptyItem) }

        var flow = input.flow
        var needWant = input.needWant
        var fixedVariable = input.fixedVariable

        if let locked = input.lockedTags {
            if flow != locked.flow || needWant != locked.needWant || fixedVariable != locked.fixedVariable {
                return .failure(.tagsLocked)
            }
        }

        switch flow {
        case .expense:
            guard needWant != nil else { return .failure(.needWantNeeded) }
            guard fixedVariable != nil else { return .failure(.fixedVariableNeeded) }
        case .income, .savings, .sinking:
            needWant = nil
            fixedVariable = nil
        case .transfer:
            return .failure(.transferNotAllowed)
        }

        let duplicate = existing.contains { other in
            !other.system
                && other.id != input.existingId
                && other.group.compare(group, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                && other.item.compare(item, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if duplicate { return .failure(.duplicate) }

        return .success(
            CategoryDraft(group: group, item: item, flow: flow, needWant: needWant, fixedVariable: fixedVariable)
        )
    }
}
