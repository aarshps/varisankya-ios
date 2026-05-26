import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Owns reads/writes against Firestore. Layout mirrors the Android app exactly
/// so both clients hit the same documents.
///
///   - users/{uid}/subscriptions/{sid}
///   - users/{uid}/subscriptions/{sid}/payments/{pid}      (legacy, authoritative)
///   - users/{uid}/payments/{pid}                          (flat mirror, fast All-Payments reads)
///
/// **Payments are dual-written.** The nested write is the source of truth and
/// is committed atomically with the subscription's dueDate advance; the flat
/// write is best-effort. See [[android-payment-migration]].
@MainActor
final class FirestoreService {
    static let shared = FirestoreService()

    private let db: Firestore

    init() {
        self.db = Firestore.firestore()
    }

    // MARK: Collections
    private func subsCollection(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("subscriptions")
    }

    private func nestedPayments(uid: String, subId: String) -> CollectionReference {
        subsCollection(uid: uid).document(subId).collection("payments")
    }

    private func flatPayments(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("payments")
    }

    // MARK: Live subscription list
    /// Streams every change to the user's subscription collection. Closes when
    /// the returned `ListenerRegistration` is removed.
    func observeSubscriptions(
        uid: String,
        onChange: @escaping ([Subscription]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        subsCollection(uid: uid)
            .order(by: "dueDate", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onError(error)
                    return
                }
                let docs = snapshot?.documents ?? []
                let subs: [Subscription] = docs.compactMap {
                    do {
                        return try $0.data(as: Subscription.self)
                    } catch {
                        return nil
                    }
                }
                let sorted = subs.sorted { lhs, rhs in
                    if lhs.active != rhs.active { return lhs.active && !rhs.active }
                    switch (lhs.dueDate, rhs.dueDate) {
                    case let (l?, r?): return l < r
                    case (_?, nil): return true
                    case (nil, _?): return false
                    default: return false
                    }
                }
                onChange(sorted)
            }
    }

    // MARK: One-shot fetch (used by notifications, search)
    func fetchActiveSubscriptions(uid: String) async throws -> [Subscription] {
        let snapshot = try await subsCollection(uid: uid)
            .whereField("active", isEqualTo: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Subscription.self) }
    }

    func fetchAllSubscriptions(uid: String) async throws -> [Subscription] {
        let snapshot = try await subsCollection(uid: uid).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Subscription.self) }
    }

    // MARK: Subscription mutations
    func upsert(_ subscription: Subscription, uid: String) async throws {
        var data: [String: Any] = [
            "name": subscription.name,
            "cost": subscription.cost,
            "currency": subscription.currency,
            "recurrence": subscription.recurrence,
            "category": subscription.category,
            "active": subscription.active,
            "autopay": subscription.autopay
        ]
        if let due = subscription.dueDate {
            data["dueDate"] = Timestamp(date: due)
        } else {
            data["dueDate"] = NSNull()
        }
        if let id = subscription.id {
            try await subsCollection(uid: uid).document(id).setData(data)
        } else {
            _ = try await subsCollection(uid: uid).addDocument(data: data)
        }
    }

    func setActive(_ subscription: Subscription, active: Bool, uid: String) async throws {
        guard let id = subscription.id else { return }
        try await subsCollection(uid: uid).document(id).updateData(["active": active])
    }

    func delete(_ subscription: Subscription, uid: String) async throws {
        guard let id = subscription.id else { return }
        try await subsCollection(uid: uid).document(id).delete()
    }

    // MARK: Payment dual-write (mirror of Android)
    /// Records a payment, advancing the dueDate atomically when `nextDueDate` is
    /// supplied. The nested write is authoritative; the flat write is best-effort.
    func recordPayment(
        for subscription: Subscription,
        on paymentDate: Date,
        nextDueDate: Date?,
        uid: String
    ) async throws {
        guard let subId = subscription.id else { return }

        let payment = PaymentRecord(
            date: paymentDate,
            amount: subscription.cost,
            subscriptionName: subscription.name,
            subscriptionId: subId,
            currency: subscription.currency,
            userId: uid
        )

        let subRef = subsCollection(uid: uid).document(subId)
        let paymentRef = nestedPayments(uid: uid, subId: subId).document()
        let paymentId = paymentRef.documentID

        let batch = db.batch()
        try batch.setData(from: payment, forDocument: paymentRef)
        if let next = nextDueDate {
            batch.updateData(["dueDate": Timestamp(date: next)], forDocument: subRef)
        }
        try await batch.commit()

        // Best-effort flat mirror
        Task.detached {
            do {
                try await PaymentRepository.mirrorToFlat(
                    paymentId: paymentId,
                    payment: payment,
                    uid: uid
                )
            } catch {
                // swallow — flat mirror is optimization, not source of truth
            }
        }

        // Cancel pending notification for this subscription so the tray matches in-app state
        NotificationScheduler.cancel(forSubscriptionId: subId)
    }

    // MARK: Payment reads
    func fetchPayments(for subscriptionId: String, uid: String, limit: Int = 50) async throws -> [PaymentRecord] {
        let snapshot = try await nestedPayments(uid: uid, subId: subscriptionId)
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: PaymentRecord.self) }
    }

    func fetchAllPayments(uid: String) async throws -> [PaymentRecord] {
        // Read the flat collection first (single round-trip, no composite index).
        do {
            let snapshot = try await flatPayments(uid: uid)
                .order(by: "date", descending: true)
                .getDocuments()
            if !snapshot.documents.isEmpty {
                return snapshot.documents.compactMap { try? $0.data(as: PaymentRecord.self) }
            }
        } catch {
            // Fall through to legacy nested fan-out below.
        }

        // Fallback: walk every subscription's nested payments collection. Slower
        // but always works without flat-collection rules / data.
        let subs = try await fetchAllSubscriptions(uid: uid)
        var combined: [PaymentRecord] = []
        try await withThrowingTaskGroup(of: [PaymentRecord].self) { group in
            for sub in subs {
                guard let id = sub.id else { continue }
                group.addTask {
                    try await self.fetchPayments(for: id, uid: uid, limit: 500)
                }
            }
            for try await chunk in group {
                combined.append(contentsOf: chunk)
            }
        }
        combined.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        return combined
    }

    // MARK: Payment edits
    func updatePaymentDate(payment: PaymentRecord, to newDate: Date, uid: String) async throws {
        guard let id = payment.id, !payment.subscriptionId.isEmpty else { return }
        try await nestedPayments(uid: uid, subId: payment.subscriptionId)
            .document(id)
            .updateData(["date": Timestamp(date: newDate)])

        Task.detached {
            try? await PaymentRepository.mirrorUpdateOnFlat(
                paymentId: id, updates: ["date": Timestamp(date: newDate)], uid: uid
            )
        }
    }

    func deletePayment(_ payment: PaymentRecord, uid: String) async throws {
        guard let id = payment.id, !payment.subscriptionId.isEmpty else { return }
        try await nestedPayments(uid: uid, subId: payment.subscriptionId)
            .document(id)
            .delete()

        Task.detached {
            try? await PaymentRepository.mirrorDeleteOnFlat(paymentId: id, uid: uid)
        }
    }

    /// Wipes every document the user owns. Called from the Settings → Delete
    /// Account flow before `Auth.user.delete()`. Best-effort: a partial failure
    /// here still allows the auth record to be removed so the user isn't
    /// trapped in a stuck state.
    func deleteAllUserData(uid: String) async throws {
        // Subscriptions and their nested payments
        let subsSnap = try await subsCollection(uid: uid).getDocuments()
        for doc in subsSnap.documents {
            let payments = try await doc.reference.collection("payments").getDocuments()
            for p in payments.documents {
                try? await p.reference.delete()
            }
            try? await doc.reference.delete()
        }
        // Flat payments mirror
        let flatSnap = try await flatPayments(uid: uid).getDocuments()
        for p in flatSnap.documents {
            try? await p.reference.delete()
        }
        // The user doc itself, if it exists
        try? await db.collection("users").document(uid).delete()
    }
}
