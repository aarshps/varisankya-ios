import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class MainViewModel {

    private(set) var subscriptions: [Subscription] = []
    private(set) var isLoading: Bool = true
    private(set) var error: String?
    private(set) var heroState: HeroState = HeroState()

    private var listener: ListenerRegistration?
    private var rescheduleTask: Task<Void, Never>?

    func startObserving(uid: String) {
        listener?.remove()
        isLoading = true
        error = nil

        listener = FirestoreService.shared.observeSubscriptions(uid: uid) { [weak self] subs in
            Task { @MainActor in
                guard let self else { return }
                self.subscriptions = subs
                self.heroState = Self.calculateHero(subs)
                self.isLoading = false
                self.scheduleReminders(for: subs)
            }
        } onError: { [weak self] err in
            Task { @MainActor in
                self?.error = err.localizedDescription
                self?.isLoading = false
            }
        }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    func refresh(uid: String) {
        startObserving(uid: uid)
        AppAnalytics.homeRefreshPull()
    }

    // MARK: Mutations
    func markPaid(_ subscription: Subscription, uid: String) async {
        let next = RecurrenceHelper.nextDueDate(
            from: subscription.dueDate ?? Date(),
            recurrence: subscription.recurrence
        )
        do {
            try await FirestoreService.shared.recordPayment(
                for: subscription,
                on: Date(),
                nextDueDate: next,
                uid: uid
            )
            AppAnalytics.paymentMarkPaidSwipe()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setActive(_ subscription: Subscription, active: Bool, uid: String) async {
        do {
            try await FirestoreService.shared.setActive(subscription, active: active, uid: uid)
            AppAnalytics.subscriptionStatusChange(active: active)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ subscription: Subscription, uid: String) async {
        do {
            try await FirestoreService.shared.delete(subscription, uid: uid)
            AppAnalytics.subscriptionDelete()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Hero math (mirror of MainViewModel.calculateHeroData)
    private static func calculateHero(_ allSubs: [Subscription]) -> HeroState {
        let active = allSubs.filter { $0.active && $0.dueDate != nil }
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let monthComps = cal.dateComponents([.year, .month], from: today)

        var total: Double = 0
        var overdue: [Subscription] = []

        for sub in active {
            guard let due = sub.dueDate else { continue }
            let dueDay = cal.startOfDay(for: due)
            let subComps = cal.dateComponents([.year, .month], from: dueDay)

            if dueDay < today {
                overdue.append(sub)
                total += sub.cost
            } else if subComps.year == monthComps.year && subComps.month == monthComps.month {
                total += sub.cost
            }
        }

        let nextPayment = active
            .filter { ($0.dueDate.map(cal.startOfDay(for:)) ?? .distantPast) >= today }
            .min { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        return HeroState(
            totalAmount: total,
            nextPayment: nextPayment,
            overdueSubscriptions: overdue,
            activeSubscriptions: active
        )
    }

    // MARK: Notification rescheduling — debounced
    private func scheduleReminders(for subs: [Subscription]) {
        rescheduleTask?.cancel()
        rescheduleTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return }
            await NotificationScheduler.rescheduleAll(for: subs)
        }
    }
}
