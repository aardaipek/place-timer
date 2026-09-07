import PlaceTimerCore
import SwiftUI

/// Aralık başına yer toplamları.
///
/// Eskiden dört sütunlu bir `Table`'dı: "Yer / Toplam / Aktif / Oturum".
/// Tablo sayıları hizalar ama karşılaştırmaz — hangi yerin ötekinin iki katı
/// olduğunu görmek için rakamları okuyup zihinden bölmek gerekiyordu. Süre
/// zaten uzunluk demek; her satırın kendi çubuğu bu işi göz için yapıyor.
/// Çubuk rengi yerin rengi, yani paneldeki nokta ve gün şeridiyle aynı.
struct StatisticsSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var range: StatsRange = .week

    /// `placeTotals` süreye göre azalan sıralı döner; en uzun ilk satırdır ve
    /// çubukların ölçeği ona göre kurulur.
    private var totals: [PlaceTotal] { coordinator.totals(for: range) }
    private var enUzun: TimeInterval { totals.first?.totalSeconds ?? 0 }
    private var toplam: TimeInterval { totals.reduce(0) { $0 + $1.totalSeconds } }

    var body: some View {
        Form {
            Section {
                Picker("Aralık", selection: $range) {
                    ForEach(StatsRange.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if totals.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Kayıt yok", systemImage: "chart.bar")
                    } description: {
                        Text("Bu aralıkta henüz bir oturum yok.")
                    }
                }
            } else {
                Section {
                    ForEach(totals) { total in
                        row(for: total)
                    }
                } header: {
                    HStack {
                        Text("Yerler")
                        Spacer()
                        Text(DurationFormat.readable(toplam))
                            .monospacedDigit()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func row(for total: PlaceTotal) -> some View {
        let color = PlaceColor.color(for: total.placeID)

        return VStack(alignment: .leading, spacing: Design.tight) {
            HStack(spacing: Design.small) {
                Circle()
                    .fill(color)
                    .frame(width: Design.dotSize, height: Design.dotSize)
                    .accessibilityHidden(true)

                Text(coordinator.placeName(for: total.placeID))
                    .lineLimit(1)

                Spacer(minLength: Design.small)

                Text(DurationFormat.readable(total.totalSeconds))
                    .monospacedDigit()
            }

            // Çubuk aynı sayıyı ikinci kez söylüyor; ekran okuyucuya iki kez
            // okutmanın anlamı yok.
            ProgressView(value: total.totalSeconds, total: max(enUzun, 1))
                .progressViewStyle(.linear)
                .tint(color)
                .accessibilityHidden(true)

            Text(
                "Aktif \(DurationFormat.readable(total.activeSeconds))"
                    + " · \(total.sessionCount) oturum"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.vertical, Design.tight)
    }
}

#Preview {
    StatisticsSettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .frame(width: Design.settingsPaneWidth, height: Design.settingsHeight)
}
