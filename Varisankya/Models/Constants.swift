import Foundation
import SwiftUI

enum Constants {
    static let categories: [String] = [
        "Entertainment", "Utilities", "Work", "Loan", "Software", "Family",
        "Health", "Investment", "Insurance", "Productivity", "Other"
    ]

    static let recurrencePresets: [String] = ["Monthly", "Yearly", "Weekly", "Daily", "Custom"]

    enum Anim {
        static let short: Double = 0.20
        static let medium: Double = 0.40
        static let long: Double = 0.50
        static let extraLong: Double = 1.50
    }
}
