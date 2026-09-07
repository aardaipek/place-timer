import SwiftUI

/// Tek bir izin satırı: durum, açıklama ve düzeltme yolları.
struct PermissionRow: View {
    let granted: Bool
    let title: String
    let detail: String
    let pane: SystemSettings.Pane
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Design.medium) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.title3)
                .foregroundStyle(granted ? .green : .orange)
                .accessibilityLabel(granted ? "Verildi" : "Eksik")

            VStack(alignment: .leading, spacing: Design.tight) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Design.medium)

            if !granted {
                VStack(spacing: Design.tight) {
                    Button("İzin ver", action: action)
                    Button("Sistem Ayarları", action: openPane)
                        .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, Design.tight)
    }

    private func openPane() {
        SystemSettings.open(pane)
    }
}
