import Foundation
import FirebaseFirestore

struct PaymentRecord: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var date: Date?
    var amount: Double = 0
    var subscriptionName: String = ""
    var subscriptionId: String = ""
    var currency: String = "USD"
    var userId: String = ""
}

extension PaymentRecord {
    static let preview = PaymentRecord(
        id: "p1",
        date: Date(),
        amount: 649,
        subscriptionName: "Netflix",
        subscriptionId: "sub-1",
        currency: "INR",
        userId: "u1"
    )
}
