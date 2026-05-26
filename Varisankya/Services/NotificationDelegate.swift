import Foundation
import UserNotifications
import FirebaseAuth

/// Routes incoming notification interactions to Firestore (for the "Mark Paid"
/// action) and to analytics for tap/dismiss tracking.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let subId = info["subscriptionId"] as? String

        switch response.actionIdentifier {
        case NotificationScheduler.markPaidActionId:
            AppAnalytics.notificationMarkPaidAction()
            if let subId {
                Task { @MainActor in
                    await Self.markPaidFromNotification(subscriptionId: subId)
                }
            }
        case UNNotificationDefaultActionIdentifier:
            AppAnalytics.notificationTap()
        case UNNotificationDismissActionIdentifier:
            AppAnalytics.notificationDismiss()
        default:
            break
        }

        completionHandler()
    }

    @MainActor
    private static func markPaidFromNotification(subscriptionId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let all = try await FirestoreService.shared.fetchAllSubscriptions(uid: uid)
            guard let sub = all.first(where: { $0.id == subscriptionId }) else { return }
            let next = RecurrenceHelper.nextDueDate(
                from: sub.dueDate ?? Date(),
                recurrence: sub.recurrence
            )
            try await FirestoreService.shared.recordPayment(
                for: sub,
                on: Date(),
                nextDueDate: next,
                uid: uid
            )
        } catch {
            // swallow — best-effort from a notification action
        }
    }
}
