import PlaceTimerCore
import SwiftUI

/// Yerler listesinin bir satırı: kapalıyken özet, açıkken düzenleyici.
///
/// Renk noktası paneldeki ve gün şeridindeki renkle aynı işlevden geliyor;
/// listede gördüğü rengi kullanıcı şeritte de tanısın diye.
struct PlaceRowView: View {
    @Bindable var coordinator: AppCoordinator
    let place: Place

    @State private var draftName = ""
    @State private var isExpanded = false
    @State private var confirmingDelete = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            detail
        } label: {
            summary
        }
        .onChange(of: place.displayName, initial: true) { draftName = place.displayName }
        // Ad, alan odağı bıraktığında yazılıyor. Her tuş vuruşunda kaydetmek
        // listeyi yeniden sıralar ve satır kullanıcının gözünün önünde yer
        // değiştirir; ayrı bir "Kaydet" düğmesi ise macOS'ta metin alanının
        // zaten yaptığı işi ikinci kez sorar.
        .onChange(of: nameFocused) { _, focused in
            if !focused { commitRename() }
        }
        .confirmationDialog(
            "\(place.displayName) silinsin mi?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive, action: delete)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu yerde geçirdiğin süreler geçmişte \"Silinmiş yer\" olarak kalır.")
        }
    }

    private var summary: some View {
        HStack(spacing: Design.small) {
            Circle()
                .fill(PlaceColor.color(for: place.id))
                .frame(width: Design.dotSize, height: Design.dotSize)
                .accessibilityHidden(true)

            Text(place.displayName)
                .lineLimit(1)

            Spacer(minLength: Design.small)

            Text(agSayisi)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: Design.medium) {
            LabeledContent("Ad") {
                TextField("Yerin adı", text: $draftName)
                    .focused($nameFocused)
                    .onSubmit(commitRename)
            }

            VStack(alignment: .leading, spacing: Design.tight) {
                Text("Ağlar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if place.ssids.isEmpty {
                    Label(
                        "Bu yere bağlı ağ kalmadı; artık kendiliğinden tanınmaz.",
                        systemImage: "wifi.slash"
                    )
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(place.ssids.sorted(), id: \.self) { ssid in
                    LabeledContent(ssid) {
                        Button("Ayır") { detach(ssid) }
                            .buttonStyle(.link)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Yeri sil", role: .destructive) { confirmingDelete = true }
            }
        }
        .padding(.top, Design.small)
    }

    private var agSayisi: String {
        place.ssids.isEmpty ? "ağ yok" : "\(place.ssids.count) ağ"
    }

    private var temizAd: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Boş ada ya da değişmemiş ada dokunmuyoruz; boş bırakılan alan da
    /// kullanıcı odağı verdiği andaki adına geri döner.
    private func commitRename() {
        guard !temizAd.isEmpty, temizAd != place.displayName else {
            draftName = place.displayName
            return
        }
        coordinator.renamePlace(place.id, to: temizAd)
    }

    private func detach(_ ssid: String) {
        coordinator.detachSSID(ssid, from: place.id)
    }

    private func delete() {
        coordinator.removePlace(place.id)
    }
}
