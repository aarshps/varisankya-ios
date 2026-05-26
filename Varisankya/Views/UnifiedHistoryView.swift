import SwiftUI
import Charts

struct UnifiedHistoryView: View {
    @Environment(AuthService.self) private var auth
    @Environment(Preferences.self) private var prefs
    @State private var vm = HistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroTotal

                switch vm.level {
                case .overview:
                    chart(buckets: vm.monthlyBuckets)
                    bucketList(
                        title: "Months",
                        buckets: vm.monthlyBuckets
                    ) { bucket in
                        Haptics.tick()
                        vm.level = .monthDetail(key: bucket.key, label: bucket.label)
                    }
                case .monthDetail(let key, let label):
                    backRow("All months") { vm.level = .overview }
                    let buckets = vm.dailyBuckets(monthKey: key)
                    chart(buckets: buckets, title: label)
                    bucketList(title: "Days in \(label)", buckets: buckets) { bucket in
                        Haptics.tick()
                        vm.level = .dayDetail(key: bucket.key, label: bucket.label)
                    }
                case .dayDetail(let key, let label):
                    backRow("Back") {
                        // Try to land back on the month detail if we know it.
                        let monthKey = String(key.prefix(7))
                        let monthName: String = {
                            let f = DateFormatter(); f.dateFormat = "MMM yyyy"
                            let fIn = DateFormatter(); fIn.dateFormat = "yyyy-MM"
                            if let d = fIn.date(from: monthKey) {
                                return f.string(from: d)
                            }
                            return monthKey
                        }()
                        vm.level = .monthDetail(key: monthKey, label: monthName)
                    }
                    paymentsList(forDayKey: key, label: label)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .navigationTitle("Payment History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let uid = auth.uid { await vm.load(uid: uid) }
        }
    }

    private var heroTotal: some View {
        GlassFormCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total spent")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(CurrencyHelper.format(vm.totalSpent, code: prefs.currency))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("\(vm.allPayments.count) payments")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chart(buckets: [HistoryViewModel.Bucket], title: String? = nil) -> some View {
        GlassFormCard {
            VStack(alignment: .leading, spacing: 12) {
                if let title { Text(title).font(.system(.headline, design: .rounded)) }
                if buckets.isEmpty {
                    Text("No payments yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    Chart(buckets) { bucket in
                        BarMark(
                            x: .value("Period", bucket.label),
                            y: .value("Total", bucket.total)
                        )
                        .foregroundStyle(.tint)
                        .cornerRadius(12)
                        .annotation(position: .top) {
                            Text(CurrencyHelper.compactFormat(bucket.total))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .glassEffect(in: .capsule)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisValueLabel().font(.caption2)
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 260)
                }
            }
        }
    }

    private func bucketList(
        title: String,
        buckets: [HistoryViewModel.Bucket],
        onTap: @escaping (HistoryViewModel.Bucket) -> Void
    ) -> some View {
        GlassFormCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(.headline, design: .rounded))
                if buckets.isEmpty {
                    Text("Nothing here yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(buckets.reversed()) { bucket in
                        Button { onTap(bucket) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bucket.label)
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                    Text("\(bucket.payments.count) payments")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(CurrencyHelper.format(bucket.total, code: bucket.payments.first?.currency ?? "USD"))
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        if bucket.id != buckets.reversed().last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func paymentsList(forDayKey key: String, label: String) -> some View {
        GlassFormCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(label).font(.system(.headline, design: .rounded))
                let payments = vm.payments(forDayKey: key)
                if payments.isEmpty {
                    Text("No payments on this day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(payments) { p in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.subscriptionName)
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                Text(p.currency)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(CurrencyHelper.format(p.amount, code: p.currency))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .padding(.vertical, 6)
                        if p.id != payments.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func backRow(_ text: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.click()
            action()
        } label: {
            HStack {
                Image(systemName: "chevron.left")
                Text(text).font(.system(.body, design: .rounded, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .glassEffect(in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
