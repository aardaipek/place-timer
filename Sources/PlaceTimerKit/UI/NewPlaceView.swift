import PlaceTimerCore
import SwiftUI

/// Panelden elle yer oluşturma.
///
/// Uygulamanın soru penceresi yalnızca tanınmayan bir ağ görüldüğünde çıkıyor.
/// Ağ yokken ya da bilgisayar zaten tanıdığı bir ağa bağlanmışken kullanıcının
/// yeni bir yer açacak yolu yoktu; bu pencere o boşluğu dolduruyor.
struct NewPlaceView: View {
    let coordinator: AppCoordinator
    let onFinish: () -> Void

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Design.medium) {
            Text("Yeni yer")
                .font(.headline)

            Text(aciklama)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Yerin adı", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit(commit)

            HStack {
                Spacer()
                Button("Vazgeç", role: .cancel, action: onFinish)
                    .keyboardShortcut(.cancelAction)
                Button("Ekle", action: commit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(temizAd.isEmpty)
            }
        }
        .task { nameFocused = true }
    }

    /// Kullanıcı ağın yeni yere bağlanıp bağlanmayacağını bilsin: bağlanırsa
    /// yer bir daha kendiliğinden tanınır, bağlanmazsa seçim yalnızca bu ağda
    /// kaldığı sürece geçerli.
    private var aciklama: String {
        "Şu an bulunduğun yeri adlandır. Bağlı olduğun ağ başka bir yere "
            + "kayıtlı değilse bu yere eklenir ve bir dahakine kendiliğinden "
            + "tanınır."
    }

    private var temizAd: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        guard !temizAd.isEmpty else { return }
        coordinator.createPlaceManually(named: temizAd)
        onFinish()
    }
}
