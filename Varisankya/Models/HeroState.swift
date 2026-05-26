import Foundation

struct HeroState: Equatable {
    var totalAmount: Double = 0
    var nextPayment: Subscription?
    var overdueSubscriptions: [Subscription] = []
    var activeSubscriptions: [Subscription] = []

    var hasOverdue: Bool { !overdueSubscriptions.isEmpty }
    var isFreshAccount: Bool {
        activeSubscriptions.isEmpty && nextPayment == nil
    }
    var isFinancialZen: Bool {
        !activeSubscriptions.isEmpty && totalAmount == 0 && nextPayment == nil && overdueSubscriptions.isEmpty
    }
}
