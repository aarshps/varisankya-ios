import Foundation
import FirebaseFirestore

struct Subscription: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String = ""
    var dueDate: Date?
    var cost: Double = 0
    var currency: String = "USD"
    var recurrence: String = "Monthly"
    var category: String = "Entertainment"
    var active: Bool = true
    var autopay: Bool = false
}

extension Subscription {
    static let preview = Subscription(
        id: "preview-1",
        name: "Netflix",
        dueDate: Date().addingTimeInterval(86_400 * 3),
        cost: 649,
        currency: "INR",
        recurrence: "Monthly",
        category: "Entertainment",
        active: true,
        autopay: true
    )

    var daysUntilDue: Int? {
        guard let dueDate else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let due = cal.startOfDay(for: dueDate)
        return cal.dateComponents([.day], from: today, to: due).day
    }

    var isOverdue: Bool {
        (daysUntilDue ?? 0) < 0
    }

    var statusText: String {
        guard active else { return "Inactive" }
        guard let days = daysUntilDue else { return recurrence }
        switch days {
        case ..<0: return "\(-days)d overdue"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "\(days) days"
        }
    }
}
