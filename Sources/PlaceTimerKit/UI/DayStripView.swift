import PlaceTimerCore
import SwiftUI

/// Günün oturumlarını yatay bir şerit olarak çizer.
///
/// Şerit 24 saatlik değil: günün ilk oturumundan şimdiye uzanır. Sabah 9'da
/// başlanan bir günde şeridin dörtte üçünü boş bırakmanın kimseye faydası yok.
struct DayStripView: View {
    let segments: [DaySegment]
    let now: Date

    private var start: Date? { segments.first?.start }

    private var span: TimeInterval {
        guard let start else { return 0 }
        return max(60, now.timeIntervalSince(start))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)

                    if let start {
                        ForEach(segments) { segment in
                            let offset = segment.start.timeIntervalSince(start) / span
                            let width = max(
                                2,
                                (segment.duration / span) * geometry.size.width
                            )
                            Capsule()
                                .fill(PlaceColor.color(for: segment.placeID))
                                .frame(width: width)
                                .offset(x: offset * geometry.size.width)
                        }
                    }
                }
            }
            .frame(height: 8)

            if let start {
                HStack {
                    Text(saat(start))
                    Spacer()
                    Text(saat(now))
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            }
        }
    }

    private func saat(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
