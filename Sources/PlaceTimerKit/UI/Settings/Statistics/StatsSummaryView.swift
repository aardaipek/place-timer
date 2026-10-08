import PlaceTimerCore
import SwiftUI

/// Dönemin büyük toplamı, önceki dönemle farkı ve grafiği.
struct StatsSummaryView: View {
    let coordinator: AppCoordinator
    let period: StatsPeriod

    var body: some View {
        let now = Date()
        let total = coordinator.totalSeconds(in: period)

        VStack(alignment: .leading, spacing: Design.medium) {
            VStack(alignment: .leading, spacing: Design.tight) {
                Text(period.title(now: now))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(DurationFormat.readable(total))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let comparison = comparisonText(total: total, now: now) {
                    Text(comparison)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if period.scope == .day {
                let segments = coordinator.segments(on: period.interval.start)
                if !segments.isEmpty {
                    DayStripView(segments: segments, now: min(now, period.interval.end), height: 14)
                }
            } else {
                DailyChartView(days: coordinator.dailyTotals(in: period), scope: period.scope)
                    .frame(height: 160)
            }
        }
        .padding(.vertical, Design.small)
    }

    private func comparisonText(total: TimeInterval, now: Date) -> String? {
        let previous = coordinator.previousTotalSeconds(for: period)
        guard previous > 0 || total > 0 else { return nil }
        let diff = total - previous
        guard abs(diff) >= 60 else { return "Önceki dönemle aynı" }

        let label: String
        switch (period.scope, period.contains(now)) {
        case (.day, true): label = "Dünün bu saatinden"
        case (.week, true): label = "Geçen haftanın bu anından"
        case (.month, true): label = "Geçen ayın bu anından"
        case (.day, false): label = "Önceki günden"
        case (.week, false): label = "Önceki haftadan"
        case (.month, false): label = "Önceki aydan"
        }
        let amount = DurationFormat.readable(abs(diff))
        return "\(label) \(amount) \(diff > 0 ? "fazla" : "az")"
    }
}
