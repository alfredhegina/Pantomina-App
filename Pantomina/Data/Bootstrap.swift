import Foundation
import SwiftData
import SwiftUI

enum PantominaSchema {
    static let modelContainer: ModelContainer = {
        let schema = Schema([
            PersonRecord.self,
            AccountRecord.self,
            CategoryRecord.self,
            TransactionRecord.self,
            RecurringRuleRecord.self,
            FundingPlanRecord.self,
            JarSourceRecord.self,
            LoanRecord.self,
            FundRecord.self,
            SnapshotRecord.self,
            AppMeta.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }()
}

@MainActor
enum Bootstrap {
    static func ensureMeta(_ context: ModelContext) -> AppMeta {
        let descriptor = FetchDescriptor<AppMeta>(predicate: #Predicate { $0.key == "main" })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let meta = AppMeta()
        context.insert(meta)
        try? context.save()
        return meta
    }

    static func person(id: PersonId, in context: ModelContext) -> PersonRecord? {
        let raw = id.rawValue
        let descriptor = FetchDescriptor<PersonRecord>(predicate: #Predicate { $0.personId == raw })
        return try? context.fetch(descriptor).first
    }

    static func completeOnboarding(
        fernName: String,
        starkName: String,
        fernIsPayer: Bool,
        seedStarters: Bool,
        context: ModelContext
    ) throws {
        // Roles: fern id stays fern; if stark is payer we still keep ids stable —
        // SPEC: fern=payer, stark=contributor fixed mapping for colors.
        // Onboarding assigns who fronts bills: we store fernIsPayer on meta;
        // PersonRecord.role follows fern=payer / stark=contributor always per DECISIONS.
        _ = fernIsPayer

        if Bootstrap.person(id: .fern, in: context) == nil {
            context.insert(PersonRecord(id: .fern, name: fernName.trimmingCharacters(in: .whitespacesAndNewlines)))
        } else if let p = Bootstrap.person(id: .fern, in: context) {
            p.name = fernName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if Bootstrap.person(id: .stark, in: context) == nil {
            context.insert(PersonRecord(id: .stark, name: starkName.trimmingCharacters(in: .whitespacesAndNewlines)))
        } else if let p = Bootstrap.person(id: .stark, in: context) {
            p.name = starkName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let meta = ensureMeta(context)
        meta.fernIsPayer = fernIsPayer
        meta.onboardingComplete = true

        if seedStarters {
            try SeedCatalog.seedStarterData(into: context)
        } else {
            // Always seed system categories at minimum so Add form has somewhere to go later
            let cats = try context.fetch(FetchDescriptor<CategoryRecord>())
            if cats.isEmpty {
                for seed in SeedCatalog.starterCategories where seed.system {
                    context.insert(
                        CategoryRecord(
                            group: seed.group,
                            item: seed.item,
                            flow: seed.flow,
                            needWant: seed.needWant,
                            fixedVariable: seed.fixedVariable,
                            system: true
                        )
                    )
                }
            }
        }

        try context.save()
    }
}
