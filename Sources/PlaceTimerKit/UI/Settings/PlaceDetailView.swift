import PlaceTimerCore
import SwiftUI

/// Seçili yerin ayrıntısı: ad, bağlı ağlar, silme.
struct PlaceDetailView: View {
    @Bindable var coordinator: AppCoordinator
    let place: Place

    @State private var draftName = ""
    @State private var silmeOnayi = false

    var body: some View {
        Form {
            Section("Ad") {
                // Her tus vurusunda kaydetmiyoruz: liste ada gore sirali,
                // yazarken satir gozunun onunde yer degistirirdi.
                TextField("Yerin adı", text: $draftName)
                    .onSubmit(commitRename)
                Button("Kaydet", action: commitRename)
                    .disabled(temizAd.isEmpty || temizAd == place.displayName)
            }

            Section("Ağlar") {
                if place.ssids.isEmpty {
                    Text("Bu yere bağlı ağ kalmadı; artık kendiliğinden tanınmaz.")
                        .foregroundStyle(.orange)
                }
                ForEach(place.ssids.sorted(), id: \.self) { ssid in
                    LabeledContent(ssid) {
                        Button("Ayır") { detach(ssid) }
                            .buttonStyle(.borderless)
                    }
                }
            }

            Section {
                Button("Yeri sil", role: .destructive) { silmeOnayi = true }
            }
        }
        .formStyle(.grouped)
        .onChange(of: place.id, initial: true) { draftName = place.displayName }
        .confirmationDialog(
            "\(place.displayName) silinsin mi?",
            isPresented: $silmeOnayi,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive, action: delete)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu yerde geçirdiğin süreler geçmişte \"Silinmiş yer\" olarak kalır.")
        }
    }

    private var temizAd: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitRename() {
        guard !temizAd.isEmpty else { return }
        coordinator.renamePlace(place.id, to: temizAd)
    }

    private func detach(_ ssid: String) {
        coordinator.detachSSID(ssid, from: place.id)
    }

    private func delete() {
        coordinator.removePlace(place.id)
    }
}
