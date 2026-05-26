import Foundation

struct CurrencyItem: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let symbol: String
}

enum CurrencyHelper {
    static let all: [CurrencyItem] = [
        .init(code: "INR", name: "Indian Rupee", symbol: "\u{20B9}"),
        .init(code: "USD", name: "US Dollar", symbol: "$"),
        .init(code: "EUR", name: "Euro", symbol: "\u{20AC}"),
        .init(code: "GBP", name: "British Pound", symbol: "\u{00A3}"),
        .init(code: "JPY", name: "Japanese Yen", symbol: "\u{00A5}"),
        .init(code: "AUD", name: "Australian Dollar", symbol: "$"),
        .init(code: "CAD", name: "Canadian Dollar", symbol: "$"),
        .init(code: "CHF", name: "Swiss Franc", symbol: "\u{20A3}"),
        .init(code: "CNY", name: "Chinese Yuan", symbol: "\u{00A5}"),
        .init(code: "HKD", name: "Hong Kong Dollar", symbol: "$"),
        .init(code: "NZD", name: "New Zealand Dollar", symbol: "$"),
        .init(code: "SEK", name: "Swedish Krona", symbol: "kr"),
        .init(code: "KRW", name: "South Korean Won", symbol: "\u{20A9}"),
        .init(code: "SGD", name: "Singapore Dollar", symbol: "$"),
        .init(code: "MXN", name: "Mexican Peso", symbol: "$"),
        .init(code: "KES", name: "Kenyan Shilling", symbol: "KSh"),
        .init(code: "UNT", name: "Generic Unit", symbol: "#")
    ]

    static func symbol(for code: String) -> String {
        all.first { $0.code == code }?.symbol ?? "$"
    }

    static func item(for code: String) -> CurrencyItem? {
        all.first { $0.code == code }
    }

    static func format(_ amount: Double, code: String) -> String {
        let sym = symbol(for: code)
        let rounded = amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", amount)
            : String(format: "%.2f", amount)
        return "\(sym) \(rounded)"
    }

    static func compactFormat(_ amount: Double) -> String {
        if amount == 0 { return "0" }
        let abs = Swift.abs(amount)
        switch abs {
        case 1_000_000...:
            return trim(amount / 1_000_000, suffix: "m")
        case 100_000...:
            return trim(amount / 100_000, suffix: "l")
        case 1_000...:
            return trim(amount / 1_000, suffix: "k")
        default:
            return String(format: "%.0f", amount)
        }
    }

    private static func trim(_ value: Double, suffix: String) -> String {
        let formatted = String(format: "%.1f", value)
        if formatted.hasSuffix(".0") {
            return String(formatted.dropLast(2)) + suffix
        }
        return formatted + suffix
    }
}
