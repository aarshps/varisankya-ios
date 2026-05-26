import SwiftUI

struct HeroSection: View {
    let state: HeroState
    let currency: String
    var onTap: () -> Void

    private var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMM"
        return f.string(from: Date())
    }

    private var label: String {
        if state.hasOverdue { return "Overdue" }
        if state.activeSubscriptions.isEmpty && state.nextPayment == nil {
            return "Get Started"
        }
        if state.activeSubscriptions.isEmpty == false && state.totalAmount == 0 {
            return "Financial Zen"
        }
        return "Remaining in \(monthName)"
    }

    private var primaryText: String {
        if state.hasOverdue {
            let n = state.overdueSubscriptions.count
            return "\(n) \(n == 1 ? "Item" : "Items")"
        }
        if state.activeSubscriptions.isEmpty && state.nextPayment == nil {
            return "Welcome"
        }
        if state.activeSubscriptions.isEmpty == false && state.totalAmount == 0 {
            return "All Clear"
        }
        return CurrencyHelper.format(state.totalAmount, code: currency)
    }

    private var primaryTint: Color {
        if state.hasOverdue { return .red }
        if state.activeSubscriptions.isEmpty == false && state.totalAmount == 0 { return .accentColor }
        return .primary
    }

    private var labelTint: Color {
        state.hasOverdue ? .red : .secondary
    }

    var body: some View {
        Button(action: { onTap() }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(label)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(labelTint)
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text(primaryText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTint)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.4), value: primaryText)

                if let next = state.nextPayment, !state.hasOverdue {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Next: \(next.name) \(next.statusText)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: 32))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        HeroSection(state: HeroState(
            totalAmount: 1840,
            nextPayment: .preview,
            overdueSubscriptions: [],
            activeSubscriptions: [.preview]
        ), currency: "INR", onTap: {})
        HeroSection(state: HeroState(
            totalAmount: 0,
            nextPayment: nil,
            overdueSubscriptions: [.preview],
            activeSubscriptions: [.preview]
        ), currency: "INR", onTap: {})
    }
    .padding()
    .background(Color(.systemBackground))
}
