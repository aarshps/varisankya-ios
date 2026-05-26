import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {

    private(set) var all: [Subscription] = []
    private(set) var loading = false
    private(set) var error: String?

    var query: String = ""
    var selectedCategories: Set<String> = []
    var autopayFilter: AutopayFilter = .any
    var statusFilter: StatusFilter = .any

    enum AutopayFilter { case any, autopay, manual }
    enum StatusFilter { case any, active, inactive }

    func load(uid: String) async {
        loading = true
        error = nil
        do {
            all = try await FirestoreService.shared.fetchAllSubscriptions(uid: uid)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    var filtered: [Subscription] {
        all.filter { sub in
            if !query.isEmpty {
                if !sub.name.localizedCaseInsensitiveContains(query) &&
                   !sub.category.localizedCaseInsensitiveContains(query) {
                    return false
                }
            }
            if !selectedCategories.isEmpty && !selectedCategories.contains(sub.category) {
                return false
            }
            switch autopayFilter {
            case .any: break
            case .autopay: if !sub.autopay { return false }
            case .manual: if sub.autopay { return false }
            }
            switch statusFilter {
            case .any: break
            case .active: if !sub.active { return false }
            case .inactive: if sub.active { return false }
            }
            return true
        }
    }
}
