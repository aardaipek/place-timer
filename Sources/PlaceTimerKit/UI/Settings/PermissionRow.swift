import SwiftUI

/// Tek bir izin satırı: durum, açıklama ve düzeltme yolları.
///
/// Eskiden iki düğme sağda alt alta duruyordu ("İzin ver" ve "Sistem
/// Ayarları"); ikisi aynı ağırlıkta görünüyor, satırın yüksekliğini de
/// gereksiz yere iki katına çıkarıyordu. Artık sağda tek bir eylem var —
/// izin verilmişse eylem de yok, yalnız durum — ve Sistem Ayarları, ancak
/// gerektiğinde açıklamanın altında bir bağlantı olarak beliriyor.
struct PermissionRow: View {
    let granted: Bool
    let title: String
    let detail: String
    let pane: SystemSettings.Pane
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Design.medium) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(granted ? Color.green : Color.orange)
                .accessibilityLabel(granted ? "Verildi" : "Eksik")

            VStack(alignment: .leading, spacing: Design.tight) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !granted {
                    Button("Sistem Ayarları'nda aç", action: openPane)
                        .buttonStyle(.link)
                        .padding(.top, Design.tight)
                }
            }

            Spacer(minLength: Design.medium)

            if granted {
                Text("Verildi")
                    .foregroundStyle(.secondary)
            } else {
                Button("İzin ver", action: action)
            }
        }
        .padding(.vertical, Design.tight)
    }

    private func openPane() {
        SystemSettings.open(pane)
    }
}
