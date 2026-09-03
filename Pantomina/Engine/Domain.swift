import Foundation

enum Scope: String, CaseIterable, Codable, Sendable {
    case household
    case fern
    case stark
    case business
}

enum FlowType: String, CaseIterable, Codable, Sendable {
    case income
    case expense
    case transfer
    case savings
    case sinking
}

enum NeedWant: String, Codable, Sendable {
    case need
    case want
}

enum FixedVariable: String, Codable, Sendable {
    case fixed
    case variable
}

enum RealizedStatus: String, CaseIterable, Codable, Sendable {
    case realized
    case pending
    case projected
}

enum AccountKind: String, Codable, Sendable {
    case cash
    case ewallet
    case bank
    case digitalBank = "digital_bank"
    case creditCard = "credit_card"
    case savingsAsset = "savings_asset"
    case investment
    case govMandated = "gov_mandated"
    case receivable
    case loan
}

enum SettlementKind: String, Codable, Sendable {
    case instant
    case statement
}

struct Allocation: Equatable, Sendable {
    var fern: Int
    var stark: Int

    var total: Int { fern + stark }
}

/// Pure display helper: never store the returned string.
enum AccountLabels {
    static func display(baseName: String, scope: Scope, personName: String) -> String {
        switch scope {
        case .household, .business:
            return baseName
        case .fern, .stark:
            return "\(baseName) · \(personName)"
        }
    }

    static func greeting(fernName: String, fernPet: String?, starkName: String, starkPet: String?) -> String {
        let a = (fernPet?.isEmpty == false) ? fernPet! : fernName
        let b = (starkPet?.isEmpty == false) ? starkPet! : starkName
        return "Hi, \(a) & \(b)."
    }
}

enum AllocationDefaults {
    static func forAmount(_ amountC: Int, accountScope: Scope, paidBy: PersonId) -> Allocation {
        switch accountScope {
        case .household, .business:
            let fernShare = (amountC + 1) / 2
            return Allocation(fern: fernShare, stark: amountC - fernShare)
        case .fern, .stark:
            switch paidBy {
            case .fern: return Allocation(fern: amountC, stark: 0)
            case .stark: return Allocation(fern: 0, stark: amountC)
            }
        }
    }

    static func justMine(amountC: Int, paidBy: PersonId) -> Allocation {
        switch paidBy {
        case .fern: return Allocation(fern: amountC, stark: 0)
        case .stark: return Allocation(fern: 0, stark: amountC)
        }
    }

    static func fiftyFifty(amountC: Int) -> Allocation {
        forAmount(amountC, accountScope: .household, paidBy: .fern)
    }
}
