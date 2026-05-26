import SwiftUI

struct MainView: View {
    @Environment(AuthService.self) private var auth
    @Environment(Preferences.self) private var prefs
    @State private var vm = MainViewModel()

    @State private var showAddSheet = false
    @State private var editing: Subscription?
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showLogo = true
    @Namespace private var glassNamespace

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                content
                    .refreshable {
                        guard let uid = auth.uid else { return }
                        vm.refresh(uid: uid)
                    }

                addButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Varisankya")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                        Haptics.click()
                    } label: {
                        ProfileBadge(url: auth.photoURL)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                        AppAnalytics.screenSearchOpen()
                        Haptics.click()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .toolbarBackground(.automatic, for: .navigationBar)
            .sheet(isPresented: $showAddSheet) {
                AddSubscriptionSheet(existing: nil) { _ in }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.thinMaterial)
            }
            .sheet(item: $editing) { sub in
                AddSubscriptionSheet(existing: sub) { _ in }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.thinMaterial)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .sheet(isPresented: $showSearch) {
                NavigationStack { SearchView() }
            }
            .navigationDestination(isPresented: $showHistory) {
                UnifiedHistoryView()
            }
        }
        .task {
            guard let uid = auth.uid else { return }
            vm.startObserving(uid: uid)
            await requestNotificationsIfNeeded()
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn, let uid = auth.uid {
                vm.startObserving(uid: uid)
            } else {
                vm.stopObserving()
            }
        }
    }

    // MARK: Content
    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeroSection(state: vm.heroState, currency: prefs.currency) {
                    showHistory = true
                    AppAnalytics.screenAllPaymentsOpen()
                    Haptics.click()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if vm.isLoading && vm.subscriptions.isEmpty {
                    LoadingSkeleton()
                        .padding(.horizontal, 16)
                } else if vm.subscriptions.isEmpty {
                    EmptyState {
                        showAddSheet = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 48)
                } else {
                    SubscriptionList(
                        subscriptions: vm.subscriptions,
                        currency: prefs.currency,
                        onTap: { sub in editing = sub; AppAnalytics.subscriptionEditOpen() },
                        onMarkPaid: { sub in
                            Task { if let uid = auth.uid { await vm.markPaid(sub, uid: uid) } }
                        },
                        onToggleActive: { sub in
                            Task { if let uid = auth.uid { await vm.setActive(sub, active: !sub.active, uid: uid) } }
                        },
                        onDelete: { sub in
                            Task { if let uid = auth.uid { await vm.delete(sub, uid: uid) } }
                        }
                    )
                    .padding(.horizontal, 16)
                }

                Color.clear.frame(height: 100) // FAB clearance
            }
        }
    }

    private var addButton: some View {
        Button {
            showAddSheet = true
            AppAnalytics.subscriptionAddOpen()
            Haptics.success()
        } label: {
            Label("Add Subscription", systemImage: "plus")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .tint(.accentColor)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private func requestNotificationsIfNeeded() async {
        guard !prefs.notificationPermissionRequested else { return }
        let granted = await NotificationScheduler.requestAuthorization()
        prefs.notificationPermissionRequested = true
        if granted {
            await NotificationScheduler.rescheduleAll(for: vm.subscriptions)
        }
    }
}

private struct ProfileBadge: View {
    let url: URL?
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit()
                            .foregroundStyle(.tint)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(.circle)
        .glassEffect(in: .circle)
    }
}

#Preview {
    MainView()
        .environment(AuthService.shared)
        .environment(Preferences.shared)
}
