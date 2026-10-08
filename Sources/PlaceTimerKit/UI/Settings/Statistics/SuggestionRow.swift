import PlaceTimerCore
import SwiftUI

struct SuggestionRow: View {
    let suggestion: Suggestion
    let coordinator: AppCoordinator

    var body: some View {
        let text = SuggestionText.make(suggestion, coordinator: coordinator)

        HStack(alignment: .firstTextBaseline, spacing: Design.medium) {
            Image(systemName: "wand.and.sparkles")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(text.title)
                Text(text.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Design.small)
            Button("Yoksay") { coordinator.dismiss(suggestion) }
                .buttonStyle(.glass)
            Button(text.action) { coordinator.apply(suggestion) }
                .buttonStyle(.glassProminent)
        }
        .padding(.vertical, Design.tight)
    }
}
