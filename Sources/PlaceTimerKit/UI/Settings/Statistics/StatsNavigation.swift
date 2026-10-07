import Foundation
import PlaceTimerCore
import Observation
import SwiftUI

/// İstatistikte hangi dönemin gösterildiği.
///
/// Kontroller pencerenin başlığında, liste bölümün içinde duruyor; ikisi aynı
/// dönemi okusun diye durum ayarlar penceresinde tutuluyor. Bölümler arasında
/// gidip gelince seçilen hafta da korunuyor.
@MainActor
@Observable
final class StatsNavigation {
    var scope: StatsScope = .week {
        didSet {
            guard scope != oldValue else { return }
            period = .containing(Date(), scope: scope)
        }
    }

    var period = StatsPeriod.containing(Date(), scope: .week)

    /// Dışa aktarma anında üretilir; gövdede kurulsaydı her çizimde bütün
    /// dönemin CSV'si yeniden yazılırdı.
    var exportDocument: CSVDocument?
    var exporting = false

    var showsCurrentPeriod: Bool { period.contains(Date()) }

    func previous() { period = period.shifted(by: -1) }
    func next() { period = period.shifted(by: 1) }
    func today() { period = .containing(Date(), scope: scope) }

    func export(using coordinator: AppCoordinator) {
        exportDocument = CSVDocument(text: coordinator.csv(in: period))
        exporting = true
    }
}

/// Başlığın sağındaki dönem kontrolleri. Hepsi tek bir cam grupta: kabuk
/// sabit kalıyor, yalnızca bu yuva doluyor.
struct StatsHeaderControls: View {
    @Bindable var navigation: StatsNavigation
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        GlassEffectContainer(spacing: Design.small) {
            HStack(spacing: Design.small) {
                Picker("Ölçek", selection: $navigation.scope) {
                    ForEach(StatsScope.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Button("Önceki", systemImage: "chevron.left", action: navigation.previous)
                Button("Bugün", action: navigation.today)
                    .disabled(navigation.showsCurrentPeriod)
                Button("Sonraki", systemImage: "chevron.right", action: navigation.next)
                    .disabled(navigation.showsCurrentPeriod)

                Button("Geri al", systemImage: "arrow.uturn.backward", action: coordinator.undoLastEdit)
                    .keyboardShortcut("z")
                    .disabled(!coordinator.canUndo)
                Button("Dışa aktar…", systemImage: "square.and.arrow.up") {
                    navigation.export(using: coordinator)
                }
            }
            .buttonStyle(.glass)
            .labelStyle(.iconOnly)
            .controlSize(.small)
            .fixedSize()
        }
    }
}
