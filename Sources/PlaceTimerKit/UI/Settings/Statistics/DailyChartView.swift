import Charts
import PlaceTimerCore
import SwiftUI

/// Haftanın ya da ayın günleri, yerlere göre yığılmış çubuklar. Renk yerin
/// rengi: paneldeki nokta ve gün şeridiyle aynı dil.
struct DailyChartView: View {
    let days: [DayTotal]
    let scope: StatsScope

    var body: some View {
        Chart {
            ForEach(days) { day in
                ForEach(day.shares) { share in
                    BarMark(
                        x: .value("Gün", day.day, unit: .day),
                        y: .value("Saat", share.seconds / 3600)
                    )
                    .foregroundStyle(PlaceColor.color(for: share.placeID))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: scope == .week ? 1 : 7)) {
                AxisValueLabel(format: scope == .week ? .dateTime.weekday(.abbreviated) : .dateTime.day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let saat = value.as(Double.self) { Text("\(Int(saat))sa") }
                }
            }
        }
        .environment(\.locale, Locale(identifier: "tr_TR"))
        .accessibilityLabel("Günlük süre grafiği")
    }
}
