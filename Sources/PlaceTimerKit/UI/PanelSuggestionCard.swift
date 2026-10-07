import PlaceTimerCore
import SwiftUI

/// Paneldeki tek öneri. Gerçekten yüzen bir şey olduğu için cam: sayaç
/// metninin üstünde, gelip giden bir kart.
struct PanelSuggestionCard: View {
    let suggestion: Suggestion
    let remaining: Int
    let coordinator: AppCoordinator

    var body: some View {
        let text = SuggestionText.make(suggestion, coordinator: coordinator)

        VStack(alignment: .leading, spacing: Design.small) {
            Label(text.title, systemImage: "wand.and.sparkles")
                .font(.subheadline.weight(.semibold))
            Text(text.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Design.small) {
                Button(text.action) { coordinator.apply(suggestion) }
                    .buttonStyle(.glassProminent)
                Button("Yoksay") { coordinator.dismiss(suggestion) }
                    .buttonStyle(.glass)
                Spacer(minLength: 0)
                if remaining > 0 {
                    Button("+\(remaining) öneri") {
                        PlaceTimerAppDelegate.shared?.presentSettings(tab: .istatistik)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
        .padding(Design.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}
