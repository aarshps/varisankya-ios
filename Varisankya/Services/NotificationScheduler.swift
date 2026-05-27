import Foundation
import UserNotifications
import FirebaseAuth

/// Schedules per-subscription due-date reminders using UNUserNotificationCenter.
///
/// **Why scheduled-local, not silent-push:** The Android app uses WorkManager
/// to run a daily worker that queries Firestore and posts notifications. iOS
/// background processing is much more restricted — we cannot reliably wake on
/// a schedule to make a network call. So instead, every time the app is
/// foregrounded (or a sub is added/edited/paid), we **re-schedule** local
/// notifications for each active subscription at the user's chosen
/// hour:minute, anchored to the wall-clock day before due date.
///
/// This produces the same UX as Android (a notification at 8:00 AM N days
/// before each subscription's due date) without depending on remote pushes.
enum NotificationScheduler {

    static let categoryIdentifier = "com.hora.varisankya.subscriptionReminder"
    static let markPaidActionId = "MARK_PAID_ACTION"

    /// Configures the notification category with a "Mark Paid" action. Call once
    /// at app startup before requesting permission.
    static func configureCategories() {
        let markPaid = UNNotificationAction(
            identifier: markPaidActionId,
            title: "Mark Paid",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [markPaid],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Requests permission. Returns true if granted (or previously authorised).
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    /// Clears every previously-scheduled subscription reminder. Call before
    /// rescheduling so we don't accumulate stale ones.
    static func clearAllScheduled() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Cancels the delivered/pending notification for one subscription. Used
    /// after the user pays or deletes a subscription.
    static func cancel(forSubscriptionId id: String) {
        let center = UNUserNotificationCenter.current()
        let identifiers = [identifier(for: id, daysBefore: 0)]
            + (0...30).map { identifier(for: id, daysBefore: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// Re-schedules every active subscription's notification window. Mirrors
    /// the Android worker's behaviour: emit at the user's chosen hour:minute
    /// of each day from `due - notificationDays` through `due` inclusive.
    static func rescheduleAll(for subscriptions: [Subscription]) async {
        let prefs = Preferences.shared
        let hour = prefs.notificationHour
        let minute = prefs.notificationMinute
        let window = prefs.notificationDays

        clearAllScheduled()

        let center = UNUserNotificationCenter.current()
        let now = Date()
        let cal = Calendar(identifier: .gregorian)

        for sub in subscriptions where sub.active {
            guard let due = sub.dueDate, let id = sub.id else { continue }
            // Schedule one notification per day in [due - window, due]
            for daysBefore in 0...window {
                guard let triggerDay = cal.date(byAdding: .day, value: -daysBefore, to: due) else { continue }
                guard let trigger = nextFireDate(forDay: triggerDay, hour: hour, minute: minute, after: now) else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = title(forDaysLeft: daysBefore)
                let prefix = sub.autopay ? "Autopay \u{2022} " : ""
                content.body = "\(prefix)\(sub.name): \(sub.currency) \(formatAmount(sub.cost))"
                content.sound = .default
                content.categoryIdentifier = categoryIdentifier
                content.threadIdentifier = "subscriptions"
                content.userInfo = [
                    "subscriptionId": id,
                    "daysLeft": daysBefore
                ]

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: trigger)
                let calTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

                let request = UNNotificationRequest(
                    identifier: identifier(for: id, daysBefore: daysBefore),
                    content: content,
                    trigger: calTrigger
                )
                do {
                    try await center.add(request)
                } catch {
                    // skip this one — non-fatal
                }
            }
        }
        AppAnalytics.notificationWorkerScheduled()
    }

    /// User-facing diagnostic — posts a test notification right now.
    static func postTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Varisankya \u{2014} test notification"
        content.body = "If you can see this, notifications are working."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "varisankya-test-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        AppAnalytics.notificationTestSent()
    }

    // MARK: - Helpers

    private static func identifier(for subscriptionId: String, daysBefore: Int) -> String {
        "varisankya.sub.\(subscriptionId).d\(daysBefore)"
    }

    private static func title(forDaysLeft days: Int) -> String {
        switch days {
        case 0: return "Due Today"
        case 1: return "Due Tomorrow"
        default: return "Due in \(days) days"
        }
    }

    private static func nextFireDate(forDay day: Date, hour: Int, minute: Int, after: Date) -> Date? {
        let cal = Calendar(identifier: .gregorian)
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        guard let candidate = cal.date(from: comps) else { return nil }
        return candidate > after ? candidate : nil
    }

    private static func formatAmount(_ amount: Double) -> String {
        amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", amount)
            : String(format: "%.2f", amount)
    }
}
