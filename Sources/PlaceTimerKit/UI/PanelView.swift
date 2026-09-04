import PlaceTimerCore
import SwiftUI

public struct PanelView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var isRenaming = false
    @State private var draftName = ""

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let prompt = coordinator.prompt {
                PlacePromptView(prompt: prompt, coordinator: coordinator)
            } else {
                header
                counters
                if !coordinator.todaySessions.isEmpty { today }
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 6) {
            if isRenaming {
                TextField("Yerin adı", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commitRename)
                Button("Kaydet", action: commitRename)
                    .buttonStyle(.borderless)
            } else {
                Text(coordinator.placeName)
                    .font(.headline)
                Button {
                    draftName = coordinator.placeName
                    isRenaming = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .disabled(coordinator.currentPlaceID == nil)
                .help("Yerin adını değiştir")
            }
            Spacer()
        }
    }

    private var counters: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(DurationFormat.clock(coordinator.elapsed))
                .font(.system(size: 40, weight: .light, design: .rounded))
                .monospacedDigit()
            Text("Aktif çalışma \(DurationFormat.readable(coordinator.activeSeconds))")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bugün")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(coordinator.todaySessions) { session in
                HStack {
                    Text(coordinator.placeName(for: session.placeID))
                        .lineLimit(1)
                    Spacer()
                    Text(DurationFormat.range(from: session.startedAt, to: session.endedAt))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if coordinator.needsLocationPermission || coordinator.needsNotificationPermission {
                Button {
                    OnboardingWindowPresenter.shared.present(coordinator: coordinator)
                } label: {
                    Label(missingPermissionText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Çıkış") { coordinator.quit() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var missingPermissionText: String {
        if coordinator.needsLocationPermission { return "Konum izni gerekli" }
        return "Bildirim izni gerekli"
    }

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { coordinator.renameCurrentPlace(to: trimmed) }
        isRenaming = false
    }
}
