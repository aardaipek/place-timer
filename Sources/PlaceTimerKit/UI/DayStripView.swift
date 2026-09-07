import PlaceTimerCore
import SwiftUI

/// Günün oturumları, panelin tabanında ince bir şerit.
///
/// Şerit 24 saatlik değil: günün ilk oturumundan şimdiye uzanır. Sabah 9'da
/// başlanan bir günde şeridin dörtte üçünü boş bırakmanın kimseye faydası yok.
///
/// Kendi kartı yok; panelin zeminine oturan bir çizgi olarak okunur. Tek
/// oturumluk bir günde hiç gösterilmez — uçtan uca dolu tek renk hiçbir şey
/// anlatmaz, yalnızca yer kaplar.
///
/// Çizim `Canvas` ile yapılıyor: segment başına bir view yaratmak yerine tek
/// geçişte çiziliyor ve `GeometryReader`'a gerek kalmıyor.
struct DayStripView: View {
    let segments: [DaySegment]
    let now: Date

    private var start: Date? { segments.first?.start }

    private var span: TimeInterval {
        guard let start else { return 0 }
        return max(60, now.timeIntervalSince(start))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.tight) {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(height: Design.stripHeight)
            .accessibilityElement()
            .accessibilityLabel(erisilebilirlikMetni)

            if let start {
                HStack {
                    Text(start, format: .dateTime.hour().minute())
                    Spacer()
                    Text(now, format: .dateTime.hour().minute())
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .padding(.horizontal, Design.large)
            }
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard let start else { return }
        let radius = size.height / 2

        context.fill(
            Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: radius),
            with: .color(.primary.opacity(0.08))
        )

        for segment in segments {
            let offset = segment.start.timeIntervalSince(start) / span * size.width
            // Cok kisa oturumlar da gorunsun; bir piksellik segment sekmeye
            // benzemekten cikip yok olurdu.
            let width = max(size.height, segment.duration / span * size.width)
            context.fill(
                Path(
                    roundedRect: CGRect(x: offset, y: 0, width: width, height: size.height),
                    cornerRadius: radius
                ),
                with: .color(PlaceColor.color(for: segment.placeID))
            )
        }
    }

    private var erisilebilirlikMetni: String {
        guard let start else { return "Gün şeridi boş" }
        let aralik = DurationFormat.range(from: start, to: now)
        return "Gün şeridi \(aralik), \(segments.count) oturum"
    }
}
