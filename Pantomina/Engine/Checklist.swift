import Foundation

/// §4.8 checklist generation — pure. Tick = mark done; UI realizes linked ledger.
enum Checklist {
    enum Kind: String, Sendable {
        case bill
        case transfer
        case ccStatement = "cc_statement"
        case fundTranche = "fund_tranche"
        case loanPayment = "loan_payment"
    }

    struct Task: Equatable, Identifiable, Sendable {
        var id: String
        var cycleISO: String
        var title: String
        var sourceAccountId: String
        var amountC: Int
        var amountBehavior: Projection.AmountBehavior
        var kind: Kind
        var paymentsRequired: Int
        var paymentsDone: Int
        var linkedId: String?
        var done: Bool
        var pastCutoff: Bool
    }

    struct Summary: Equatable, Sendable {
        var doneCount: Int
        var totalCount: Int
        var stillToSendC: Int
    }

    struct TrancheTask: Equatable, Sendable {
        var id: String
        var title: String
        var sourceAccountId: String
        var amountC: Int
        var linkedId: String?
        var paymentsRequired: Int
        var paymentsDone: Int
        /// This cycle's tranche is complete (reserved), even if k < n overall.
        var done: Bool
    }

    static func tasks(
        cycleISO: String,
        todayISO: String,
        rules: [Projection.Rule],
        statementAccountsWithPending: [String],
        trancheTasks: [TrancheTask],
        loanSnapshots: [Loan.Snapshot] = [],
        doneIds: Set<String>
    ) -> [Task] {
        let past = todayISO > cycleISO
        var out: [Task] = []

        for rule in Projection.rows(forCycleISO: cycleISO, rules: rules) where rule.flow == .expense {
            let id = "bill-\(rule.recurringRuleId)-\(cycleISO)"
            out.append(
                Task(
                    id: id,
                    cycleISO: cycleISO,
                    title: rule.title,
                    sourceAccountId: rule.accountId,
                    amountC: rule.amountC,
                    amountBehavior: rule.amountBehavior,
                    kind: .bill,
                    paymentsRequired: 1,
                    paymentsDone: doneIds.contains(id) ? 1 : 0,
                    linkedId: rule.recurringRuleId,
                    done: doneIds.contains(id),
                    pastCutoff: past && !doneIds.contains(id)
                )
            )
        }

        for accountId in statementAccountsWithPending {
            let id = "cc-\(accountId)-\(cycleISO)"
            out.append(
                Task(
                    id: id,
                    cycleISO: cycleISO,
                    title: "Count the card",
                    sourceAccountId: accountId,
                    amountC: 0,
                    amountBehavior: .exact,
                    kind: .ccStatement,
                    paymentsRequired: 1,
                    paymentsDone: doneIds.contains(id) ? 1 : 0,
                    linkedId: accountId,
                    done: doneIds.contains(id),
                    pastCutoff: past && !doneIds.contains(id)
                )
            )
        }

        for tranche in trancheTasks {
            out.append(
                Task(
                    id: tranche.id,
                    cycleISO: cycleISO,
                    title: tranche.title,
                    sourceAccountId: tranche.sourceAccountId,
                    amountC: tranche.amountC,
                    amountBehavior: .exact,
                    kind: .fundTranche,
                    paymentsRequired: tranche.paymentsRequired,
                    paymentsDone: tranche.paymentsDone,
                    linkedId: tranche.linkedId,
                    done: tranche.done || doneIds.contains(tranche.id),
                    pastCutoff: past && !(tranche.done || doneIds.contains(tranche.id))
                )
            )
        }

        for var loanTask in Loan.checklistTasks(cycleISO: cycleISO, loans: loanSnapshots, doneIds: doneIds) {
            loanTask.pastCutoff = past && !loanTask.done
            out.append(loanTask)
        }

        return out
    }

    static func tick(taskId: String, in tasks: [Task]) -> [Task] {
        tasks.map { task in
            guard task.id == taskId else { return task }
            var t = task
            t.done = true
            t.paymentsDone = min(t.paymentsRequired, t.paymentsDone + 1)
            t.pastCutoff = false
            return t
        }
    }

    static func summary(tasks: [Task]) -> Summary {
        let done = tasks.filter(\.done).count
        let still = tasks.filter { !$0.done && $0.kind != .ccStatement }.reduce(0) { $0 + $1.amountC }
        return Summary(doneCount: done, totalCount: tasks.count, stillToSendC: still)
    }
}
