import AppKit
import PlaceTimerCore
import SwiftUI

/// Uygulama hakkında, gizlilik ve verinin tamamını silme.
///
/// Gizlilik burada bir vaat cümlesi olarak değil, doğrulanabilir bir şey
/// olarak duruyor: verinin durduğu klasör Finder'da açılabiliyor. "Hiçbir yere
/// göndermiyoruz" cümlesini kullanıcının kendi gözüyle görebilmesi, cümlenin
/// kendisinden daha ikna edici.
struct AboutSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var confirmingErase = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: Design.large) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Design.tight) {
                        Text("PlaceTimer")
                            .font(.title2.weight(.semibold))
                        Text("Sürüm \(surum)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text("Nerede ne kadar oturduğunu kendiliğinden takip eder.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, Design.small)
            }

            Section {
                Label {
                    Text(
                        "Kayıtlı yerlerin ve bütün oturum geçmişin yalnızca bu "
                            + "bilgisayarda, düz JSON dosyaları olarak duruyor. "
                            + "Hesap açman gerekmez; uygulamanın sunucusu yoktur, "
                            + "analitik toplamaz."
                    )
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.green)
                }

                Label {
                    Text(
                        "Konum izni Wi-Fi ağının adını okumak için gerekiyor: "
                            + "macOS 14'ten beri ağ adı bu izin olmadan verilmiyor. "
                            + "Koordinat da aynı adlı ağları birbirinden ayırmak için "
                            + "saklanıyor."
                    )
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.blue)
                }

                Label {
                    Text(
                        "Tek istisna: tanımadığı bir ağa bağlandığında, ad önerecek "
                            + "mekânları bulmak için o anki koordinat Apple Haritalar'a "
                            + "gönderilir. Bu arama Apple'a gider, bize değil; "
                            + "istemiyorsan sorulan yeri elle adlandırman yeter."
                    )
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "map")
                        .foregroundStyle(.orange)
                }

                LabeledContent("Verilerin yeri") {
                    Button("Finder'da göster", action: revealDataFolder)
                        .buttonStyle(.link)
                        .disabled(dataFolder == nil)
                }
            } header: {
                Text("Gizlilik")
            }

            Section {
                Button("Tüm verileri sil…", role: .destructive) {
                    confirmingErase = true
                }
            } header: {
                Text("Veriler")
            } footer: {
                Text(
                    "Kayıtlı yerlerin ve bütün oturum geçmişin silinir, sayaç "
                        + "sıfırdan başlar. Ayarların olduğu gibi kalır. Geri alınamaz."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Tüm veriler silinsin mi?",
            isPresented: $confirmingErase,
            titleVisibility: .visible
        ) {
            Button("Hepsini sil", role: .destructive) { coordinator.eraseAllData() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(
                "Kayıtlı yerlerin ve bütün oturum geçmişin silinir. "
                    + "Bu işlem geri alınamaz."
            )
        }
    }

    private var surum: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var dataFolder: URL? {
        try? URL.placeTimerSupportDirectory()
    }

    private func revealDataFolder() {
        guard let dataFolder else { return }
        NSWorkspace.shared.activateFileViewerSelecting([dataFolder])
    }
}

#Preview {
    AboutSettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .frame(width: Design.settingsPaneWidth, height: Design.settingsHeight)
}
