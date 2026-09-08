import PlaceTimerCore
import SwiftUI

/// Aralık başına yer toplamları ve o aralıktaki oturumlar.
///
/// Toplamlar eskiden dört sütunlu bir `Table`'dı: "Yer / Toplam / Aktif /
/// Oturum". Tablo sayıları hizalar ama karşılaştırmaz — hangi yerin ötekinin
/// iki katı olduğunu görmek için rakamları okuyup zihinden bölmek gerekiyordu.
/// Süre zaten uzunluk demek; her satırın kendi çubuğu bu işi göz için yapıyor.
/// Çubuk rengi yerin rengi, yani paneldeki nokta ve gün şeridiyle aynı.
///
/// Oturum listesi ise otomatik takibin yanıldığı yerleri düzeltmek için:
/// bilgisayar yanlış ağa bağlandığında ya da yer yanlış çözüldüğünde ortaya
/// çıkan oturum buradan siliniyor.
struct StatisticsSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var range: StatsRange = .week

    /// `placeTotals` süreye göre azalan sıralı döner; en uzun ilk satırdır ve
    /// çubukların ölçeği ona göre kurulur.
    private var totals: [PlaceTotal] { coordinator.totals(for: range) }
    private var enUzun: TimeInterval { totals.first?.totalSeconds ?? 0 }
    private var toplam: TimeInterval { totals.reduce(0) { $0 + $1.totalSeconds } }

    private var sessions: [Session] { coordinator.sessions(for: range) }

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
                        totalRow(for: total)
                    }
                } header: {
                    HStack {
                        Text("Yerler")
                        Spacer()
                        Text(DurationFormat.readable(toplam))
                            .monospacedDigit()
                    }
                }

                Section {
                    ForEach(sessions) { session in
                        sessionRow(for: session)
                    }
                } header: {
                    Text("Oturumlar")
                } footer: {
                    Text(
                        "Yanlış açılmış bir oturumu silebilirsin; süresi "
                            + "toplamlardan da düşer. Süren oturum silinmez — "
                            + "onu panelden \"Sayacı sıfırla\" ile kapatabilirsin."
                    )
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func totalRow(for total: PlaceTotal) -> some View {
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

    private func sessionRow(for session: Session) -> some View {
        let suruyor = session.id == coordinator.currentSessionID

        return HStack(spacing: Design.small) {
            Circle()
                .fill(PlaceColor.color(for: session.placeID))
                .frame(width: Design.dotSize, height: Design.dotSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(coordinator.placeName(for: session.placeID))
                    .lineLimit(1)
                Text(DurationFormat.range(from: session.startedAt, to: session.endedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: Design.small)

            Text(DurationFormat.readable(session.elapsed(at: Date())))
                .monospacedDigit()

            if suruyor {
                Text("sürüyor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Sil", role: .destructive) {
                    coordinator.deleteSession(session.id)
                }
                .buttonStyle(.link)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    StatisticsSettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .frame(width: Design.settingsPaneWidth, height: Design.settingsHeight)
}
