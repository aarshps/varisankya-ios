import Foundation

/// Mirrors the Android string-encoded recurrence model so the same Firestore
/// document is readable on both platforms. Strings like "Monthly", "Yearly",
/// "Every 3 Months", "Custom".
enum RecurrenceHelper {
    static func encode(unit: String, frequency: Int) -> String {
        if unit == "Custom" { return "Custom" }
        if frequency <= 1 { return unit }
        let plural: String
        switch unit {
        case "Monthly": plural = "Months"
        case "Yearly": plural = "Years"
        case "Weekly": plural = "Weeks"
        case "Daily": plural = "Days"
        default: plural = unit
        }
        return "Every \(frequency) \(plural)"
    }

    /// Returns (displayUnit, frequency) for the bottom sheet to prefill.
    static func decode(_ raw: String) -> (unit: String, frequency: Int) {
        if raw == "Custom" { return ("Custom", 1) }
        if raw.hasPrefix("Every ") {
            let parts = raw.split(separator: " ")
            if parts.count >= 3, let freq = Int(parts[1]) {
                let unit: String
                switch String(parts[2]) {
                case "Months", "Month": unit = "Monthly"
                case "Years", "Year": unit = "Yearly"
                case "Weeks", "Week": unit = "Weekly"
                case "Days", "Day": unit = "Daily"
                default: unit = "Monthly"
                }
                return (unit, freq)
            }
        }
        return (raw, 1)
    }

    /// Mirrors the Android calculator that uses UTC for date math. Returns nil
    /// for "Custom" recurrences (no next date can be computed).
    static func nextDueDate(from baseDate: Date, recurrence: String) -> Date? {
        if recurrence == "Custom" { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var date = cal.startOfDay(for: baseDate)

        if recurrence.hasPrefix("Every ") {
            let parts = recurrence.split(separator: " ")
            guard parts.count >= 3, let freq = Int(parts[1]) else { return date }
            let unit = String(parts[2])
            let component: Calendar.Component
            switch unit {
            case "Months", "Month": component = .month
            case "Years", "Year": component = .year
            case "Weeks", "Week": component = .weekOfYear
            case "Days", "Day": component = .day
            default: component = .month
            }
            date = cal.date(byAdding: component, value: freq, to: date) ?? date
            return date
        }

        let component: Calendar.Component
        switch recurrence {
        case "Monthly": component = .month
        case "Yearly": component = .year
        case "Weekly": component = .weekOfYear
        case "Daily": component = .day
        default: component = .month
        }
        return cal.date(byAdding: component, value: 1, to: date)
    }
}
