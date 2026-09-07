import PlaceTimerCore
import SwiftUI

struct StatisticsSettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var range: StatsRange = .week

    private var totals: [PlaceTotal] { coordinator.totals(for: range) }

    var body: some View {
        VStack(spacing: Design.medium) {
            Picker("Aralık", selection: $range) {
                ForEach(StatsRange.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, Design.large)

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
                        Text(total.sessionCount, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, Design.large)
    }
}

#Preview {
    StatisticsSettingsView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .frame(width: Design.settingsWidth, height: Design.settingsHeight)
}
