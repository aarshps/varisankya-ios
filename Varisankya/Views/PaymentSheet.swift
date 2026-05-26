import SwiftUI

/// Mirror of Android PaymentBottomSheet — record current payment, record a
/// past payment, view and edit recent payment history.
struct PaymentSheet: View {
    let subscription: Subscription
    var onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth

    @State private var history: [PaymentRecord] = []
    @State private var loading = true
    @State private var working = false
    @State private var errorMessage: String?
    @State private var showAddDatePicker = false
    @State private var addPaymentDate: Date = Date()
    @State private var editingPayment: PaymentRecord?
    @State private var pendingDelete: PaymentRecord?

    private var projectedNext: Date? {
        RecurrenceHelper.nextDueDate(
            from: subscription.dueDate ?? Date(),
            recurrence: subscription.recurrence
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    GlassFormCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(subscription.name)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                            Text("Due: \(formattedDue)")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                            if let next = projectedNext {
                                Text("Next bill will be: \(format(next))")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Next due date: Undefined (Custom recurrence)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task { await recordPayment(date: Date(), advance: true) }
                        } label: {
                            Label("Pay current bill", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.extraLarge)
                        .disabled(working)

                        Button {
                            showAddDatePicker = true
                            Haptics.click()
                        } label: {
                            Label("Add a past/extra payment", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.extraLarge)
                        .disabled(working)
                    }

                    GlassFormCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent payments")
                                .font(.system(.headline, design: .rounded))
                            if loading {
                                ProgressView().padding(.vertical, 12)
                            } else if history.isEmpty {
                                Text("No payment history yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(history) { p in
                                    PaymentRow(payment: p) {
                                        editingPayment = p
                                    } onDelete: {
                                        pendingDelete = p
                                    }
                                    if p.id != history.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddDatePicker) {
                DateOnlyPickerSheet(date: $addPaymentDate, title: "Payment date") {
                    Task { await recordPayment(date: addPaymentDate, advance: false) }
                }
                .presentationDetents([.medium])
                .presentationBackground(.thinMaterial)
            }
            .sheet(item: $editingPayment) { payment in
                EditPaymentDateSheet(
                    initialDate: payment.date ?? Date(),
                    title: "Edit payment date"
                ) { newDate in
                    Task { await updatePaymentDate(payment, to: newDate) }
                }
                .presentationDetents([.medium])
                .presentationBackground(.thinMaterial)
            }
            .confirmationDialog(
                "Delete this payment?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                )
            ) {
                if let pending = pendingDelete {
                    Button("Delete", role: .destructive) {
                        Task { await delete(pending) }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .task { await loadHistory() }
            .onAppear { AppAnalytics.paymentManageOpen() }
        }
    }

    private var formattedDue: String {
        guard let d = subscription.dueDate else { return "—" }
        return format(d)
    }

    private func format(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM dd, yyyy"
        return f.string(from: d)
    }

    private func loadHistory() async {
        guard let uid = auth.uid, let subId = subscription.id else { loading = false; return }
        loading = true
        do {
            history = try await FirestoreService.shared.fetchPayments(for: subId, uid: uid, limit: 20)
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }

    private func recordPayment(date: Date, advance: Bool) async {
        guard let uid = auth.uid else { return }
        working = true
        errorMessage = nil
        let next = advance ? projectedNext : nil
        do {
            try await FirestoreService.shared.recordPayment(
                for: subscription,
                on: date,
                nextDueDate: next,
                uid: uid
            )
            if advance {
                AppAnalytics.paymentPayCurrent()
            } else {
                AppAnalytics.paymentAddOnly()
            }
            Haptics.success()
            onCompleted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
        working = false
    }

    private func updatePaymentDate(_ payment: PaymentRecord, to newDate: Date) async {
        guard let uid = auth.uid else { return }
        do {
            try await FirestoreService.shared.updatePaymentDate(payment: payment, to: newDate, uid: uid)
            AppAnalytics.paymentEditDate()
            await loadHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
        editingPayment = nil
    }

    private func delete(_ payment: PaymentRecord) async {
        guard let uid = auth.uid else { return }
        do {
            try await FirestoreService.shared.deletePayment(payment, uid: uid)
            AppAnalytics.paymentDelete()
            await loadHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
        pendingDelete = nil
    }
}

private struct PaymentRow: View {
    let payment: PaymentRecord
    var onEdit: () -> Void
    var onDelete: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(payment.date))
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                Text(payment.currency)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(CurrencyHelper.format(payment.amount, code: payment.currency))
                .font(.system(.body, design: .rounded, weight: .semibold))
            Menu {
                Button("Edit Date", systemImage: "calendar") { onEdit() }
                Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func formatDate(_ d: Date?) -> String {
        guard let d else { return "—" }
        let f = DateFormatter(); f.dateFormat = "MMM dd, yyyy"
        return f.string(from: d)
    }
}

struct DateOnlyPickerSheet: View {
    @Binding var date: Date
    let title: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(title, selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(); dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

/// Variant that owns its own `@State` for the date and only commits on Save —
/// avoids the issue where the wheel-style picker fires the binding on every
/// frame as the wheel spins.
struct EditPaymentDateSheet: View {
    let initialDate: Date
    let title: String
    var onCommit: (Date) -> Void

    @State private var date: Date = Date()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DateOnlyPickerSheet(
            date: $date,
            title: title,
            onSave: { onCommit(date) }
        )
        .onAppear { date = initialDate }
    }
}
