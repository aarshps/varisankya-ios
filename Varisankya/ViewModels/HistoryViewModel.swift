import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {

    private(set) var allPayments: [PaymentRecord] = []
    private(set) var loading = false
    private(set) var error: String?

    var level: Level = .overview

    enum Level: Equatable {
        case overview
        case monthDetail(key: String, label: String)
        case dayDetail(key: String, label: String)
    }

    func load(uid: String) async {
        loading = true
        error = nil
        do {
            allPayments = try await FirestoreService.shared.fetchAllPayments(uid: uid)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    // MARK: Aggregations

    struct Bucket: Identifiable, Hashable {
        let id = UUID()
        let key: String
        let label: String
        let payments: [PaymentRecord]
        var total: Double { payments.reduce(0) { $0 + $1.amount } }
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd"
        return f
    }()
    private static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var monthlyBuckets: [Bucket] {
        let grouped = Dictionary(grouping: allPayments) { p -> String in
            guard let d = p.date else { return "unknown" }
            return Self.monthKeyFormatter.string(from: d)
        }
        return grouped.map { key, payments in
            let label: String
            if let any = payments.first?.date {
                label = Self.monthFormatter.string(from: any)
            } else {
                label = key
            }
            return Bucket(key: key, label: label, payments: payments)
        }
        .sorted { $0.key < $1.key }
    }

    func dailyBuckets(monthKey: String) -> [Bucket] {
        let monthPayments = allPayments.filter { p in
            guard let d = p.date else { return false }
            return Self.monthKeyFormatter.string(from: d) == monthKey
        }
        let grouped = Dictionary(grouping: monthPayments) { p -> String in
            guard let d = p.date else { return "unknown" }
            return Self.dayKeyFormatter.string(from: d)
        }
        return grouped.map { key, payments in
            let label: String
            if let any = payments.first?.date {
                label = Self.dayFormatter.string(from: any)
            } else { label = key }
            return Bucket(key: key, label: label, payments: payments)
        }
        .sorted { $0.key < $1.key }
    }

    func payments(forDayKey day: String) -> [PaymentRecord] {
        allPayments
            .filter { p in
                guard let d = p.date else { return false }
                return Self.dayKeyFormatter.string(from: d) == day
            }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    var totalSpent: Double {
        allPayments.reduce(0) { $0 + $1.amount }
    }
}
