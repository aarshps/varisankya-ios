import SwiftUI

struct EmptyState: View {
    var onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "tray.full")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.tint)
                .padding(28)
                .glassEffect(in: .circle)

            VStack(spacing: 6) {
                Text("No subscriptions yet")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text("Add your first subscription to start tracking due dates and total spend.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button {
                Haptics.success()
                onAddTapped()
            } label: {
                Label("Add subscription", systemImage: "plus")
                    .frame(minWidth: 200, minHeight: 50)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingSkeleton: View {
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14).fill(.tertiary).frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 6).fill(.tertiary).frame(height: 12)
                        RoundedRectangle(cornerRadius: 6).fill(.quaternary).frame(width: 120, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 10).fill(.tertiary).frame(width: 72, height: 30)
                }
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 24))
            }
        }
        .opacity(pulse ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

#Preview {
    VStack {
        EmptyState(onAddTapped: {})
        LoadingSkeleton()
    }
    .padding()
}
