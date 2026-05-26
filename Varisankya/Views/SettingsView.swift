import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(Preferences.self) private var prefs

    @State private var showCurrencyPicker = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showAbout = false
    @State private var showTimePicker = false
    @State private var hapticsOn: Bool = true
    @State private var biometricOn: Bool = false
    @State private var googleFontOn: Bool = true
    @State private var notificationDays: Double = 7
    @State private var notificationHour: Int = 8
    @State private var notificationMinute: Int = 0
    @State private var deleteError: String?
    @State private var deleting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileCard()

                GlassFormCard {
                    SelectionRow(
                        label: "Currency",
                        value: "\(prefs.currency)  \(CurrencyHelper.symbol(for: prefs.currency))"
                    ) {
                        showCurrencyPicker = true
                    }
                }

                GlassFormCard {
                    VStack(spacing: 14) {
                        SectionLabel("Appearance")
                        Picker("Theme", selection: Binding(
                            get: { prefs.appearance },
                            set: { prefs.appearance = $0; AppAnalytics.settingThemeChange($0.rawValue) }
                        )) {
                            ForEach(Preferences.Appearance.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Divider()

                        Toggle(isOn: $googleFontOn) {
                            LabelStack(title: "Rounded font",
                                       subtitle: "Use the brand rounded font everywhere")
                        }
                        .tint(.accentColor)
                        .onChange(of: googleFontOn) { _, on in
                            prefs.useGoogleFont = on
                            AppAnalytics.settingFontChange(on ? "rounded" : "system")
                        }
                    }
                }

                GlassFormCard {
                    VStack(spacing: 14) {
                        SectionLabel("Notifications")
                        SelectionRow(
                            label: "Reminder time",
                            value: timeText
                        ) { showTimePicker = true }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Days before due")
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(notificationDays)) days")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            }
                            Slider(value: $notificationDays, in: 0...10, step: 1)
                                .tint(.accentColor)
                                .onChange(of: notificationDays) { _, v in
                                    prefs.notificationDays = Int(v)
                                    AppAnalytics.settingNotificationDaysChange(Int(v))
                                }
                        }

                        Divider()

                        Button {
                            Task { await NotificationScheduler.postTestNotification() }
                            Haptics.success()
                        } label: {
                            Label("Send test notification", systemImage: "bell.badge")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glass)
                    }
                }

                GlassFormCard {
                    VStack(spacing: 14) {
                        SectionLabel("Security")
                        Toggle(isOn: $biometricOn) {
                            LabelStack(
                                title: "App Lock",
                                subtitle: "Require \(BiometricAuth.displayName) to open the app"
                            )
                        }
                        .tint(.accentColor)
                        .disabled(!BiometricAuth.isAvailable)
                        .onChange(of: biometricOn) { _, on in
                            handleBiometricToggle(on: on)
                        }
                    }
                }

                GlassFormCard {
                    VStack(spacing: 14) {
                        SectionLabel("Haptics")
                        Toggle(isOn: $hapticsOn) {
                            LabelStack(title: "Haptic feedback",
                                       subtitle: "Subtle vibration on actions")
                        }
                        .tint(.accentColor)
                        .onChange(of: hapticsOn) { _, on in
                            prefs.hapticsEnabled = on
                            AppAnalytics.settingHapticsToggle(on)
                            if on { Haptics.success() }
                        }
                    }
                }

                GlassFormCard {
                    VStack(spacing: 14) {
                        SectionLabel("Legal & info")
                        Link(destination: URL(string: "https://github.com/aarshps/varisankya-android/blob/main/PRIVACY.md")!) {
                            HStack {
                                Image(systemName: "lock.shield")
                                Text("Privacy Policy")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(.primary)
                        }
                        Divider()
                        Button {
                            showAbout = true
                            AppAnalytics.screenAboutOpen()
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("About Varisankya")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)
                .padding(.top, 8)

                Button(role: .destructive) {
                    showDeleteAccountConfirm = true
                    Haptics.warning()
                } label: {
                    Label("Delete account", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)
                .tint(.red)

                Text("Deleting your account removes all subscription and payment data permanently.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(18)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showCurrencyPicker) {
            SelectionSheet(
                title: "Currency",
                options: CurrencyHelper.all.map { "\($0.code)  \($0.symbol)" },
                selected: "\(prefs.currency)  \(CurrencyHelper.symbol(for: prefs.currency))"
            ) { picked in
                let code = String(picked.split(separator: " ").first ?? Substring(prefs.currency))
                prefs.currency = code
                AppAnalytics.settingCurrencyChange(code)
            }
            .presentationDetents([.large])
            .presentationBackground(.thinMaterial)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(hour: $notificationHour, minute: $notificationMinute) {
                prefs.setNotificationTime(hour: notificationHour, minute: notificationMinute)
                AppAnalytics.settingNotificationTimeChange()
            }
            .presentationDetents([.medium])
            .presentationBackground(.thinMaterial)
        }
        .sheet(isPresented: $showAbout) { AboutSheet() }
        .confirmationDialog("Sign out of Varisankya?", isPresented: $showSignOutConfirm) {
            Button("Sign out", role: .destructive) {
                try? auth.signOut()
                dismiss()
            }
        }
        .confirmationDialog(
            "Permanently delete your account?",
            isPresented: $showDeleteAccountConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) {
                Task {
                    deleting = true
                    deleteError = nil
                    do {
                        try await auth.deleteAccount()
                        dismiss()
                    } catch {
                        deleteError = "Couldn't delete: \(error.localizedDescription)\n\nSign out, sign back in, and try again."
                    }
                    deleting = false
                }
            }
        } message: {
            Text("This removes your sign-in, every subscription, and every payment record. The action cannot be undone.")
        }
        .alert("Delete failed", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .overlay {
            if deleting {
                ProgressView("Deleting account…")
                    .padding(24)
                    .glassEffect(in: .rect(cornerRadius: 20))
            }
        }
        .onAppear {
            hapticsOn = prefs.hapticsEnabled
            biometricOn = prefs.biometricEnabled
            googleFontOn = prefs.useGoogleFont
            notificationDays = Double(prefs.notificationDays)
            notificationHour = prefs.notificationHour
            notificationMinute = prefs.notificationMinute
            AppAnalytics.screenSettingsOpen()
        }
    }

    private var timeText: String {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.hour = notificationHour
        comps.minute = notificationMinute
        guard let d = cal.date(from: comps) else { return "—" }
        let f = DateFormatter(); f.dateFormat = "hh:mm a"
        return f.string(from: d)
    }

    private func handleBiometricToggle(on: Bool) {
        Task {
            if on {
                guard BiometricAuth.isAvailable else {
                    biometricOn = false
                    return
                }
                let ok = await BiometricAuth.authenticate(reason: "Confirm \(BiometricAuth.displayName) for App Lock")
                if ok {
                    prefs.biometricEnabled = true
                    AppAnalytics.settingAppLockToggle(true)
                } else {
                    biometricOn = false
                }
            } else {
                prefs.biometricEnabled = false
                AppAnalytics.settingAppLockToggle(false)
            }
        }
    }
}

// MARK: Helpers

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            Spacer()
        }
    }
}

private struct ProfileCard: View {
    @Environment(AuthService.self) private var auth
    var body: some View {
        GlassFormCard {
            HStack(spacing: 14) {
                Group {
                    if let url = auth.photoURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default:
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable().scaledToFit()
                            }
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit()
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(.circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.displayName ?? "Signed in")
                        .font(.system(.headline, design: .rounded))
                    Text(auth.email ?? "")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }
}

struct TimePickerSheet: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Date = Date()

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Reminder time",
                    selection: $selection,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                Spacer()
            }
            .navigationTitle("Reminder time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: selection)
                        hour = comps.hour ?? 8
                        minute = comps.minute ?? 0
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = minute
                if let d = Calendar.current.date(from: comps) { selection = d }
            }
        }
    }
}
