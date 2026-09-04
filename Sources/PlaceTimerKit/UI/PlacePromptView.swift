import PlaceTimerCore
import SwiftUI

/// Tanınmayan bir ağa bağlanıldığında bir kereliğine sorulan ekran.
struct PlacePromptView: View {
    let prompt: PlacePrompt
    let coordinator: AppCoordinator

    @State private var customName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text("Ağ: \(prompt.ssid)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !mergeCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(mergeCandidates) { place in
                        Button("Burası \(place.displayName)") {
                            coordinator.mergeIntoPlace(place.id)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Yakındaki mekânlar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(suggestions, id: \.self) { name in
                        Button(name) { coordinator.createPlace(named: name) }
                            .buttonStyle(.bordered)
                    }
                }
            }

            HStack {
                TextField("Kendin yaz", text: $customName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commit)
                Button("Ekle", action: commit)
                    .disabled(trimmedName.isEmpty)
            }

            Button("Şimdilik atla") { coordinator.skipPrompt() }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private var title: String {
        switch prompt {
        case .newNetwork: "Burası neresi?"
        case .possibleBranch(_, let existing, _):
            "\(existing.displayName)'in başka bir şubesi mi?"
        }
    }

    private var suggestions: [String] {
        switch prompt {
        case .newNetwork(_, let suggestions, _): suggestions
        case .possibleBranch(_, _, let suggestions): suggestions
        }
    }

    private var mergeCandidates: [Place] {
        switch prompt {
        case .newNetwork(_, _, let candidates): candidates
        case .possibleBranch(_, let existing, _): [existing]
        }
    }

    private var trimmedName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        guard !trimmedName.isEmpty else { return }
        coordinator.createPlace(named: trimmedName)
    }
}
