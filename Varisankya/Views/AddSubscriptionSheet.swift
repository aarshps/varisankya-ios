import SwiftUI

/// Mirror of Android AddSubscriptionBottomSheet. Creates or edits a Subscription.
struct AddSubscriptionSheet: View {
    let existing: Subscription?
    var onSaved: (Subscription) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(Preferences.self) private var prefs

    @State private var name: String = ""
    @State private var cost: String = ""
    @State private var dueDate: Date = Date()
    @State private var recurrenceUnit: String = "Monthly"
    @State private var frequency: String = "1"
    @State private var category: String = "Entertainment"
    @State private var active: Bool = true
    @State private var autopay: Bool = false

    @State private var showCategoryPicker = false
    @State private var showRecurrencePicker = false
    @State private var showPaymentSheet = false
    @State private var deleteRequested = false
    @State private var working = false
    @State private var errorMessage: String?

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    GlassFormCard {
                        VStack(spacing: 14) {
                            FormField(label: "Name") {
                                TextField("Netflix, Internet, Loan EMI…", text: $name)
                                    .textInputAutocapitalization(.words)
                            }
                            FormField(label: "Due date") {
                                DatePicker("", selection: $dueDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            }
                            FormField(label: "Amount") {
                                HStack(spacing: 6) {
                                    Text(CurrencyHelper.symbol(for: prefs.currency))
                                        .foregroundStyle(.secondary)
                                    TextField("0", text: $cost)
                                        .keyboardType(.decimalPad)
                                }
                            }
                        }
                    }

                    GlassFormCard {
                        VStack(spacing: 14) {
                            SelectionRow(label: "Recurrence", value: recurrenceUnit) {
                                showRecurrencePicker = true
                            }
                            if recurrenceUnit != "Custom" {
                                FormField(label: "Every") {
                                    HStack(spacing: 6) {
                                        TextField("1", text: $frequency)
                                            .keyboardType(.numberPad)
                                            .frame(maxWidth: 60)
                                        Text(unitPlural)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            SelectionRow(label: "Category", value: category) {
                                showCategoryPicker = true
                            }
                        }
                    }

                    GlassFormCard {
                        VStack(spacing: 14) {
                            Toggle(isOn: $autopay) {
                                LabelStack(title: "Autopay",
                                           subtitle: "Bank will debit this automatically")
                            }
                            .tint(.accentColor)

                            if isEditing {
                                Divider()
                                Toggle(isOn: $active) {
                                    LabelStack(title: "Active",
                                               subtitle: "Pause to stop tracking due dates")
                                }
                                .tint(.accentColor)
                            }
                        }
                    }

                    if isEditing {
                        Button {
                            showPaymentSheet = true
                            Haptics.click()
                        } label: {
                            Label("Mark Paid…", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.extraLarge)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .navigationTitle(isEditing ? "Edit Subscription" : "Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || working)
                        .fontWeight(.semibold)
                }
                if isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            deleteRequested = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .toolbarBackground(.automatic, for: .navigationBar)
            .confirmationDialog(
                "Delete this subscription?",
                isPresented: $deleteRequested
            ) {
                Button("Delete", role: .destructive) { Task { await deleteSubscription() } }
            }
            .sheet(isPresented: $showCategoryPicker) {
                SelectionSheet(
                    title: "Category",
                    options: prefs.personalized(prefix: "category", defaultList: Constants.categories),
                    selected: category
                ) { picked in
                    category = picked
                    prefs.recordUsage(prefix: "category", value: picked)
                }
                .presentationDetents([.medium])
                .presentationBackground(.thinMaterial)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showRecurrencePicker) {
                SelectionSheet(
                    title: "Recurrence",
                    options: prefs.personalized(prefix: "recurrence", defaultList: Constants.recurrencePresets),
                    selected: recurrenceUnit
                ) { picked in
                    recurrenceUnit = picked
                    if picked == "Custom" { frequency = "1" }
                    prefs.recordUsage(prefix: "recurrence", value: picked)
                }
                .presentationDetents([.medium])
                .presentationBackground(.thinMaterial)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPaymentSheet) {
                if let existing {
                    PaymentSheet(subscription: makeUpdatedSubscription(from: existing)) {
                        dismiss()
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.thinMaterial)
                }
            }
            .onAppear { prefill() }
        }
    }

    private var unitPlural: String {
        switch recurrenceUnit {
        case "Monthly": return "Months"
        case "Yearly": return "Years"
        case "Weekly": return "Weeks"
        case "Daily": return "Days"
        default: return recurrenceUnit
        }
    }

    private func prefill() {
        guard let existing else { return }
        name = existing.name
        cost = existing.cost.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", existing.cost)
            : String(format: "%.2f", existing.cost)
        dueDate = existing.dueDate ?? Date()
        category = existing.category
        active = existing.active
        autopay = existing.autopay

        let decoded = RecurrenceHelper.decode(existing.recurrence)
        recurrenceUnit = decoded.unit
        frequency = String(decoded.frequency)
    }

    private func makeUpdatedSubscription(from base: Subscription) -> Subscription {
        var sub = base
        sub.name = name
        sub.cost = Double(cost) ?? 0
        sub.dueDate = dueDate
        sub.currency = prefs.currency
        sub.recurrence = RecurrenceHelper.encode(unit: recurrenceUnit, frequency: Int(frequency) ?? 1)
        sub.category = category
        sub.active = active
        sub.autopay = autopay
        return sub
    }

    private func save() async {
        guard let uid = auth.uid else { return }
        working = true
        errorMessage = nil

        let amount = Double(cost) ?? 0
        let encodedRec = RecurrenceHelper.encode(unit: recurrenceUnit, frequency: Int(frequency) ?? 1)

        var sub = existing ?? Subscription()
        sub.name = name.trimmingCharacters(in: .whitespaces)
        sub.cost = amount
        sub.dueDate = dueDate
        sub.currency = prefs.currency
        sub.recurrence = encodedRec
        sub.category = category
        sub.active = isEditing ? active : true
        sub.autopay = autopay

        do {
            try await FirestoreService.shared.upsert(sub, uid: uid)
            AppAnalytics.subscriptionSave(isNew: !isEditing, recurrence: encodedRec)
            Haptics.success()
            onSaved(sub)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
        working = false
    }

    private func deleteSubscription() async {
        guard let uid = auth.uid, let existing else { return }
        do {
            try await FirestoreService.shared.delete(existing, uid: uid)
            AppAnalytics.subscriptionDelete()
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Helpers (reused by other sheets)

struct GlassFormCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 14) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: 28))
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            content
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SelectionRow: View {
    let label: String
    let value: String
    var action: () -> Void
    var body: some View {
        Button(action: { Haptics.click(); action() }) {
            HStack {
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct LabelStack: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .medium))
            Text(subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AddSubscriptionSheet(existing: nil) { _ in }
        .environment(AuthService.shared)
        .environment(Preferences.shared)
}
