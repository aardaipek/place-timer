import PlaceTimerCore
import SwiftUI

struct PlacesSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var selection: UUID?
    @State private var silinecek: Place?
    @State private var draftName = ""

    var body: some View {
        HSplitView {
            List(coordinator.knownPlaces, selection: $selection) { place in
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.displayName)
                    Text("\(place.ssids.count) ağ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(place.id)
            }
            .frame(minWidth: 180, maxHeight: .infinity)

            detay
                .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
        }
        // TabView icinde HSplitView kendi ideal yuksekligine buzusup pencerenin
        // altina yapisiyor; dikeyde acikca genislemesini soylemek gerekiyor.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "\(silinecek?.displayName ?? "") silinsin mi?",
            isPresented: Binding(
                get: { silinecek != nil },
                set: { if !$0 { silinecek = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                if let silinecek { coordinator.removePlace(silinecek.id) }
                selection = nil
                silinecek = nil
            }
            Button("Vazgeç", role: .cancel) { silinecek = nil }
        } message: {
            Text("Bu yerde geçirdiğin süreler geçmişte \"Silinmiş yer\" olarak kalır.")
        }
    }

    private func commitRename(_ place: Place) {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        coordinator.renamePlace(place.id, to: trimmed)
    }

    @ViewBuilder
    private var detay: some View {
        if let place = coordinator.knownPlaces.first(where: { $0.id == selection }) {
            Form {
                Section("Ad") {
                    // Her tus vurusunda kaydetmiyoruz: liste ada gore sirali,
                    // yazarken satir gozunun onunde yer degistirirdi.
                    TextField("Yerin adı", text: $draftName)
                        .onSubmit { commitRename(place) }
                    Button("Kaydet") { commitRename(place) }
                        .disabled(draftName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty)
                }

                Section("Ağlar") {
                    if place.ssids.isEmpty {
                        Text("Bu yere bağlı ağ kalmadı; artık kendiliğinden tanınmaz.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    ForEach(place.ssids.sorted(), id: \.self) { ssid in
                        HStack {
                            Text(ssid).lineLimit(1)
                            Spacer()
                            Button("Ayır") {
                                coordinator.detachSSID(ssid, from: place.id)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section {
                    Button("Yeri sil", role: .destructive) { silinecek = place }
                }
            }
            .formStyle(.grouped)
            .onChange(of: place.id, initial: true) { draftName = place.displayName }
        } else {
            ContentUnavailableView(
                "Yer seçilmedi",
                systemImage: "mappin.slash",
                description: Text("Soldaki listeden bir yer seç.")
            )
        }
    }
}
