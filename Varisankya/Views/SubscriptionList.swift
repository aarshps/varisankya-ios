import SwiftUI

struct SubscriptionList: View {
    let subscriptions: [Subscription]
    let currency: String
    var onTap: (Subscription) -> Void
    var onMarkPaid: (Subscription) -> Void
    var onToggleActive: (Subscription) -> Void
    var onDelete: (Subscription) -> Void

    @State private var pendingDelete: Subscription?

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            VStack(spacing: 8) {
                ForEach(subscriptions) { sub in
                    SubscriptionRow(subscription: sub, currency: currency)
                        .onTapGesture {
                            Haptics.click()
                            onTap(sub)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                onMarkPaid(sub)
                                Haptics.success()
                            } label: {
                                Label("Paid", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                pendingDelete = sub
                                Haptics.warning()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)

                            Button {
                                onToggleActive(sub)
                                Haptics.click()
                            } label: {
                                Label(sub.active ? "Pause" : "Resume",
                                      systemImage: sub.active ? "pause.fill" : "play.fill")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "")?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { sub in
            Button("Delete", role: .destructive) {
                onDelete(sub)
                Haptics.success()
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { sub in
            Text("This permanently removes \(sub.name) and its payment history.")
        }
    }
}

struct SubscriptionRow: View {
    let subscription: Subscription
    let currency: String

    private var pillTint: Color {
        guard subscription.active else { return .secondary }
        guard let days = subscription.daysUntilDue else { return .secondary }
        if days < 0 { return .red }
        if days <= 3 { return .orange }
        return .accentColor
    }

    var body: some View {
        HStack(spacing: 14) {
            CategoryGlyph(category: subscription.category)

            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(subscription.active ? .primary : .secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(subscription.recurrence)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    if subscription.autopay {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Autopay")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(CurrencyHelper.format(subscription.cost, code: currency))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(subscription.active ? .primary : .secondary)

                StatusPill(text: subscription.statusText, tint: pillTint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 24))
        .opacity(subscription.active ? 1 : 0.65)
    }
}

private struct StatusPill: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.18), in: .capsule)
            .foregroundStyle(tint)
            .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 0.5))
    }
}

private struct CategoryGlyph: View {
    let category: String

    private var icon: String {
        switch category {
        case "Entertainment": return "play.tv"
        case "Utilities": return "bolt"
        case "Work": return "briefcase"
        case "Loan": return "indianrupeesign.bank.building"
        case "Software": return "app.dashed"
        case "Family": return "house"
        case "Health": return "heart"
        case "Investment": return "chart.line.uptrend.xyaxis"
        case "Insurance": return "shield"
        case "Productivity": return "bolt.heart"
        default: return "creditcard"
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.tint)
            .frame(width: 44, height: 44)
            .background(.tint.opacity(0.14), in: .circle)
    }
}

#Preview {
    VStack {
        SubscriptionRow(subscription: .preview, currency: "INR")
        SubscriptionRow(subscription: {
            var s = Subscription.preview
            s.dueDate = Date().addingTimeInterval(-86_400 * 2)
            return s
        }(), currency: "INR")
    }
    .padding()
}
