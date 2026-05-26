import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(Preferences.self) private var prefs
    @State private var vm = SearchViewModel()
    @State private var editing: Subscription?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                searchField
                filters
                results
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            if let uid = auth.uid { await vm.load(uid: uid) }
        }
        .sheet(item: $editing) { sub in
            AddSubscriptionSheet(existing: sub) { _ in
                Task { if let uid = auth.uid { await vm.load(uid: uid) } }
            }
            .presentationDetents([.large])
            .presentationBackground(.thinMaterial)
            .presentationDragIndicator(.visible)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search by name or category", text: $vm.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(in: .capsule)
    }

    private var filters: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Filters").font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(text: "Autopay", isOn: vm.autopayFilter == .autopay) {
                        vm.autopayFilter = vm.autopayFilter == .autopay ? .any : .autopay
                    }
                    Chip(text: "Manual", isOn: vm.autopayFilter == .manual) {
                        vm.autopayFilter = vm.autopayFilter == .manual ? .any : .manual
                    }
                    Chip(text: "Active", isOn: vm.statusFilter == .active) {
                        vm.statusFilter = vm.statusFilter == .active ? .any : .active
                    }
                    Chip(text: "Paused", isOn: vm.statusFilter == .inactive) {
                        vm.statusFilter = vm.statusFilter == .inactive ? .any : .inactive
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Constants.categories, id: \.self) { cat in
                        Chip(text: cat, isOn: vm.selectedCategories.contains(cat)) {
                            if vm.selectedCategories.contains(cat) {
                                vm.selectedCategories.remove(cat)
                            } else {
                                vm.selectedCategories.insert(cat)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if vm.loading && vm.all.isEmpty {
            VStack { ProgressView() }.frame(maxWidth: .infinity, minHeight: 200)
        } else if vm.filtered.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No results")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
            .glassEffect(in: .rect(cornerRadius: 28))
        } else {
            SubscriptionList(
                subscriptions: vm.filtered,
                currency: prefs.currency,
                onTap: { sub in editing = sub },
                onMarkPaid: { _ in },
                onToggleActive: { _ in },
                onDelete: { _ in }
            )
        }
    }
}

private struct Chip: View {
    let text: String
    let isOn: Bool
    var action: () -> Void
    var body: some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            Text(text)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background {
                    if isOn {
                        Capsule().fill(Color.accentColor)
                    }
                }
                .glassEffect(in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { SearchView() }
        .environment(AuthService.shared)
        .environment(Preferences.shared)
}
