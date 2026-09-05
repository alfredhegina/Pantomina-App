import SwiftUI
import SwiftData

struct CatalogPocketSheet: View {
    let fernName: String
    let starkName: String
    let existing: [LedgerCatalog.ExistingPocket]
    let record: AccountRecord?
    let inUse: Bool
    let onCancel: () -> Void
    let onSave: (LedgerCatalog.PocketDraft) -> Void

    @State private var baseName = ""
    @State private var scope: Scope = .fern
    @State private var kind: AccountKind = .cash
    @State private var cutoff: Int = 15
    @State private var error: String?

    private var isEditing: Bool { record != nil }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(Color.pantomina.terraDeep)
                    }
                }
                Section {
                    TextField("Name", text: $baseName)
                        .onChange(of: baseName) { _, new in
                            let limited = InputBounds.limiting(new, max: InputBounds.maxDisplayNameLength)
                            if limited != new { baseName = limited }
                        }
                    Picker("Whose", selection: $scope) {
                        ForEach(LedgerCatalog.userScopes, id: \.rawValue) { value in
                            Text(DisplayLabels.scope(value, fernName: fernName, starkName: starkName))
                                .tag(value)
                        }
                    }
                    .disabled(inUse)
                    Picker("Kind", selection: $kind) {
                        ForEach(LedgerCatalog.userKinds, id: \.rawValue) { value in
                            Text(DisplayLabels.accountKind(value)).tag(value)
                        }
                    }
                    .disabled(inUse)
                    if kind == .creditCard {
                        Picker("Statement day", selection: $cutoff) {
                            Text(DisplayLabels.statementCutoff(15)).tag(15)
                            Text(DisplayLabels.statementCutoff(30)).tag(30)
                        }
                        .disabled(inUse)
                    }
                } footer: {
                    if inUse {
                        Text(DisplayLabels.catalogPocketIssue(.shapeLocked))
                    } else {
                        Text("Names update when you rename someone. Credit cards wait on a statement day.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pantomina.ground)
            .navigationTitle(isEditing ? "Edit pocket" : "Add a pocket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { submit() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { load() }
        }
        .presentationDetents([.large])
    }

    private func load() {
        guard let record else { return }
        baseName = record.baseName
        scope = record.scope
        kind = record.kind
        cutoff = record.statementCutoff ?? 15
    }

    private func submit() {
        let locked: LedgerCatalog.PocketShape? = inUse
            ? LedgerCatalog.PocketShape(scope: scope, kind: kind, statementCutoff: kind == .creditCard ? cutoff : nil)
            : nil
        let result = LedgerCatalog.validatePocket(
            .init(
                baseName: baseName,
                scope: scope,
                kind: kind,
                statementCutoff: kind == .creditCard ? cutoff : nil,
                existingId: record?.id,
                lockedShape: locked
            ),
            existing: existing
        )
        switch result {
        case .success(let draft):
            onSave(draft)
        case .failure(let issue):
            error = DisplayLabels.catalogPocketIssue(issue)
        }
    }
}

struct CatalogCategorySheet: View {
    let existing: [LedgerCatalog.ExistingCategory]
    let record: CategoryRecord?
    let inUse: Bool
    let onCancel: () -> Void
    let onSave: (LedgerCatalog.CategoryDraft) -> Void

    @State private var group = ""
    @State private var item = ""
    @State private var flow: FlowType = .expense
    @State private var needWant: NeedWant = .need
    @State private var rhythm: FixedVariable = .fixed
    @State private var error: String?

    private var isEditing: Bool { record != nil }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(Color.pantomina.terraDeep)
                    }
                }
                Section {
                    TextField("Group", text: $group)
                        .onChange(of: group) { _, new in
                            let limited = InputBounds.limiting(new, max: InputBounds.maxDisplayNameLength)
                            if limited != new { group = limited }
                        }
                    TextField("Item", text: $item)
                        .onChange(of: item) { _, new in
                            let limited = InputBounds.limiting(new, max: InputBounds.maxDisplayNameLength)
                            if limited != new { item = limited }
                        }
                    Picker("Flow", selection: $flow) {
                        ForEach(LedgerCatalog.userFlows, id: \.rawValue) { value in
                            Text(DisplayLabels.flow(value)).tag(value)
                        }
                    }
                    .disabled(inUse)
                    if flow == .expense {
                        Picker("Need or want", selection: $needWant) {
                            Text(DisplayLabels.needWant(.need)).tag(NeedWant.need)
                            Text(DisplayLabels.needWant(.want)).tag(NeedWant.want)
                        }
                        .disabled(inUse)
                        Picker("Rhythm", selection: $rhythm) {
                            Text(DisplayLabels.fixedVariable(.fixed)).tag(FixedVariable.fixed)
                            Text(DisplayLabels.fixedVariable(.variable)).tag(FixedVariable.variable)
                        }
                        .disabled(inUse)
                    }
                } footer: {
                    if inUse {
                        Text(DisplayLabels.catalogCategoryIssue(.tagsLocked))
                    } else {
                        Text("Group and item, no person's name in the label.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pantomina.ground)
            .navigationTitle(isEditing ? "Edit category" : "Add a category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { submit() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { load() }
        }
        .presentationDetents([.large])
    }

    private func load() {
        guard let record else { return }
        group = record.group
        item = record.item
        flow = record.flow
        needWant = record.needWant ?? .need
        rhythm = record.fixedVariable ?? .fixed
    }

    private func submit() {
        let locked: LedgerCatalog.CategoryTags? = inUse
            ? LedgerCatalog.CategoryTags(
                flow: flow,
                needWant: flow == .expense ? needWant : nil,
                fixedVariable: flow == .expense ? rhythm : nil
            )
            : nil
        let result = LedgerCatalog.validateCategory(
            .init(
                group: group,
                item: item,
                flow: flow,
                needWant: flow == .expense ? needWant : nil,
                fixedVariable: flow == .expense ? rhythm : nil,
                existingId: record?.id,
                lockedTags: locked,
                system: false
            ),
            existing: existing
        )
        switch result {
        case .success(let draft):
            onSave(draft)
        case .failure(let issue):
            error = DisplayLabels.catalogCategoryIssue(issue)
        }
    }
}
