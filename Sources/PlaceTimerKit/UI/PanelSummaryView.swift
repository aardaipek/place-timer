import PlaceTimerCore
import SwiftUI

/// Sayaç ve onu açıklayan satırlar.
///
/// Eskiden üç sayı vardı ve üçü birbirine çok yakın değerleri iki ayrı biçimde
/// tekrarlıyordu: "1:39:25" ile "Aktif 1sa 38dk · Bugün burada 1sa 39dk".
/// Okuyan kişi farkın ne olduğunu çıkaramıyordu. Burada her sayı bir kez ve
/// kendi etiketiyle geçer; büyük olan hangi soruyu cevapladığını altındaki tek
/// satırdan söyler.
struct PanelSummaryView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: Design.medium) {
            VStack(alignment: .leading, spacing: Design.tight) {
                Text(sayac)
                    .font(.system(.largeTitle, design: .rounded, weight: .light))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("Bu oturum \(DurationFormat.readable(coordinator.elapsed))")

                Text("Bu oturum")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Design.tight) {
                if let started = coordinator.sessionStartedAt {
                    LabeledContent(
                        "Başlangıç",
                        value: started.formatted(date: .omitted, time: .shortened)
                    )
                }
                LabeledContent(
                    "Aktif",
                    value: DurationFormat.readable(coordinator.activeSeconds)
                )
                LabeledContent(
                    "Bugün burada",
                    value: DurationFormat.readable(coordinator.todayHereSeconds)
                )
            }
            .font(.callout)
            .monospacedDigit()
            .labeledContentStyle(.panelStat)
        }
        .animation(.snappy, value: coordinator.elapsed)
    }

    private var sayac: String {
        DurationFormat.clock(
            coordinator.elapsed,
            showSeconds: coordinator.preferences.showSeconds
        )
    }
}

#Preview {
    PanelSummaryView(coordinator: AppCoordinator(directory: .temporaryDirectory))
        .padding()
        .frame(width: Design.panelWidth)
}
