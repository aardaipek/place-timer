import PlaceTimerCore
import SwiftUI

/// Gün bölümündeki tek oturum. Ana metin saat aralığı; yer adı yalnızca o gün
/// birden çok yer varsa görünür — tek yerli bir günde her satırda "Home"
/// yazmak bilgi değil gürültü.
struct SessionRowView: View {
    let session: Session
    let placeName: String
    let showsPlace: Bool
    let isCurrent: Bool
    /// Oturumun bu güne düşen kısmı.
    let seconds: TimeInterval

    var body: some View {
        HStack(spacing: Design.small) {
            Circle()
                .fill(PlaceColor.color(for: session.placeID))
                .frame(width: Design.dotSize, height: Design.dotSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(DurationFormat.range(from: session.startedAt, to: session.endedAt))
                    .monospacedDigit()
                if showsPlace {
                    Text(placeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Design.small)

            if isCurrent {
                Text("sürüyor")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Text(DurationFormat.readable(seconds))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
