import SwiftUI

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "v\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "indianrupeesign.circle.fill")
                        .resizable().scaledToFit()
                        .frame(width: 96, height: 96)
                        .foregroundStyle(.tint)
                        .padding(.top, 8)
                        .glassEffect(in: .circle)

                    VStack(spacing: 6) {
                        Text("Varisankya")
                            .font(.system(.title, design: .rounded, weight: .semibold))
                        Text(versionString)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    GlassFormCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Track every recurring bill — subscriptions, EMIs, school fees — without losing the calm look of iOS.")
                                .font(.system(.body, design: .rounded))
                            Text("Sync stays private inside your own Firebase project. Notifications are scheduled locally — no remote tracking.")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    GlassFormCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Link("Source on GitHub",
                                 destination: URL(string: "https://github.com/aarshps/varisankya-ios")!)
                            Link("Android sibling app",
                                 destination: URL(string: "https://github.com/aarshps/varisankya-android")!)
                            Link("Privacy Policy",
                                 destination: URL(string: "https://github.com/aarshps/varisankya-android/blob/main/PRIVACY.md")!)
                        }
                        .font(.system(.body, design: .rounded, weight: .medium))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview { AboutSheet() }
