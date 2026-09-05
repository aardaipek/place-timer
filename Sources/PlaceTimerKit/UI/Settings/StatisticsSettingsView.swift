import PlaceTimerCore
import SwiftUI

struct StatisticsSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var range: StatsRange = .week

    private var totals: [PlaceTotal] { coordinator.totals(for: range) }

    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $range) {
                ForEach(StatsRange.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)

            if totals.isEmpty {
                ContentUnavailableView(
                    "Kayıt yok",
                    systemImage: "chart.bar",
                    description: Text("Bu aralıkta henüz bir oturum yok.")
                )
            } else {
                Table(totals) {
                    TableColumn("Yer") { total in
                        Text(coordinator.placeName(for: total.placeID))
                    }
                    TableColumn("Toplam") { total in
                        Text(DurationFormat.readable(total.totalSeconds))
                            .monospacedDigit()
                    }
                    TableColumn("Aktif") { total in
                        Text(DurationFormat.readable(total.activeSeconds))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Oturum") { total in
                        Text("\(total.sessionCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}
