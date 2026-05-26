import Foundation
import FirebaseFirestore

/// Best-effort mirror helpers — mirror of Android `util/PaymentRepository`. Flat
/// collection writes are optimization only; failures are swallowed.
enum PaymentRepository {
    private static var db: Firestore { Firestore.firestore() }

    private static func flat(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("payments")
    }

    static func mirrorToFlat(paymentId: String, payment: PaymentRecord, uid: String) async throws {
        try flat(uid: uid).document(paymentId).setData(from: payment)
    }

    static func mirrorUpdateOnFlat(paymentId: String, updates: [String: Any], uid: String) async throws {
        try await flat(uid: uid).document(paymentId).updateData(updates)
    }

    static func mirrorDeleteOnFlat(paymentId: String, uid: String) async throws {
        try await flat(uid: uid).document(paymentId).delete()
    }
}
