import SwiftUI

/// Reusable bottom-sheet picker for category/recurrence/currency/etc.
struct SelectionSheet: View {
    let title: String
    let options: [String]
    let selected: String
    var onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            onPick(option)
                            Haptics.success()
                            dismiss()
                        } label: {
                            HStack {
                                Text(option)
                                    .font(.system(.body, design: .rounded, weight: option == selected ? .semibold : .regular))
                                Spacer()
                                if option == selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(in: .rect(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SelectionSheet(
        title: "Category",
        options: Constants.categories,
        selected: "Entertainment"
    ) { _ in }
}
