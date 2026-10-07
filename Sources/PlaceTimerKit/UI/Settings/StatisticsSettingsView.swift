import PlaceTimerCore
import SwiftUI

/// Laptopla geçen süre: gün, hafta, ay ve geçmişleri.
///
/// Üstte asıl sorunun cevabı (toplam ve önceki dönemle fark), altında
/// öneriler, yerler ve günlere bölünmüş oturumlar. Dönem seçimi ve gezinme
/// ayarlar penceresinin başlığında (`StatsHeaderControls`); içerikte kontrol
/// kalabalığı yok.
///
/// Oturumlar `List` içinde: seçim, ⌫ ile silme ve sağ tık menüsü `Form`'da
/// yok. Satır içi "Sil" linkleri bu yüzden kalktı.
struct StatisticsSettingsView: View {
    @Bindable var coordinator: AppCoordinator

    @Bindable var navigation: StatsNavigation
    @State private var selection: Set<UUID> = []
    @State private var editing: Session?
    @State private var editError: SessionHistory.EditError?
    @State private var showsEditError = false

    private var period: StatsPeriod { navigation.period }

    var body: some View {
        let days = coordinator.sessionDays(in: period)
        let totals = coordinator.totals(in: period)
        let periodTotal = totals.reduce(0) { $0 + $1.totalSeconds }

        List(selection: $selection) {
            Section {
                StatsSummaryView(coordinator: coordinator, period: period)
            }

            if !coordinator.suggestions.isEmpty {
                Section {
                    ForEach(coordinator.suggestions) { suggestion in
                        SuggestionRow(suggestion: suggestion, coordinator: coordinator)
                            .selectionDisabled()
                    }
                    if coordinator.offersLongerGap {
                        HStack {
                            Text("Bu aralıkları sık birleştiriyorsun. Ara eşiğini 1 saate çıkarayım mı?")
                                .font(.callout)
                            Spacer()
                            Button("Eşiği 1 saate çıkar", action: coordinator.adoptLongerGap)
                                .buttonStyle(.glass)
                        }
                        .selectionDisabled()
                    }
                } header: {
                    HStack {
                        Text("Öneriler")
                        Spacer()
                        Button("Tümünü uygula", action: coordinator.applyAllSuggestions)
                            .buttonStyle(.link)
                    }
                }
            }

            if !totals.isEmpty {
                Section("Yerler") {
                    ForEach(totals) { total in
                        placeRow(total, of: periodTotal)
                            .selectionDisabled()
                    }
                }
            }

            ForEach(days) { day in
                Section {
                    ForEach(day.sessions) { session in
                        SessionRowView(
                            session: session,
                            placeName: coordinator.placeName(for: session.placeID),
                            showsPlace: day.placeCount > 1,
                            isCurrent: session.id == coordinator.currentSessionID,
                            seconds: overlap(of: session, with: dayInterval(day.day), now: Date())
                        )
                        .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text(StatsPeriod.containing(day.day, scope: .day).title(now: Date()))
                        Spacer()
                        Text(DurationFormat.readable(day.total))
                            .monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if days.isEmpty && coordinator.suggestions.isEmpty {
                ContentUnavailableView {
                    Label("Kayıt yok", systemImage: "chart.bar")
                } description: {
                    Text("Bu dönemde henüz bir oturum yok.")
                }
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            sessionMenu(ids)
        } primaryAction: { ids in
            if ids.count == 1, let id = ids.first { editing = coordinator.session(id: id) }
        }
        .onDeleteCommand {
            coordinator.deleteSessions(selection)
            selection = []
        }
        .onChange(of: period) {
            // Görünmeyen satırlar ⌫ ile silinmesin.
            selection = []
        }
        .sheet(item: $editing) { session in
            SessionEditView(coordinator: coordinator, session: session)
        }
        .fileExporter(
            isPresented: $navigation.exporting,
            document: navigation.exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "PlaceTimer \(period.title(now: Date()))"
        ) { _ in }
        .onChange(of: editError) { _, yeni in
            showsEditError = yeni != nil
        }
        .alert("Birleştirilemedi", isPresented: $showsEditError, presenting: editError) { _ in
            Button("Tamam", role: .cancel) { editError = nil }
        } message: { error in
            Text(EditErrorText.message(error))
        }
    }

    /// Yaz saati günlerinde 23 ya da 25 saat; sabit 86.400 saniye bir saat
    /// kaydırırdı.
    private func dayInterval(_ day: Date) -> DateInterval {
        Calendar.placeTimer.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 86_400)
    }

    /// Seçimde yalnızca açık oturum varsa silinecek bir şey yok.
    private func onlyCurrent(_ ids: Set<UUID>) -> Bool {
        guard let current = coordinator.currentSessionID else { return false }
        return ids == [current]
    }

    @ViewBuilder
    private func sessionMenu(_ ids: Set<UUID>) -> some View {
        if ids.count == 1, let id = ids.first {
            Button("Düzenle…") { editing = coordinator.session(id: id) }
            Button("Öncekiyle birleştir") { editError = coordinator.mergeWithPrevious(id) }
                .disabled(coordinator.previousSession(of: id) == nil)
        } else if ids.count > 1 {
            Button("Birleştir") { editError = coordinator.mergeSessions(ids) }
        }
        Divider()
        Button("Sil", role: .destructive) {
            coordinator.deleteSessions(ids)
            selection.subtract(ids)
        }
        .disabled(onlyCurrent(ids))
    }

    private func placeRow(_ total: PlaceTotal, of periodTotal: TimeInterval) -> some View {
        let share = periodTotal > 0 ? total.totalSeconds / periodTotal : 0

        return VStack(alignment: .leading, spacing: Design.tight) {
            HStack(spacing: Design.small) {
                Circle()
                    .fill(PlaceColor.color(for: total.placeID))
                    .frame(width: Design.dotSize, height: Design.dotSize)
                    .accessibilityHidden(true)
                Text(coordinator.placeName(for: total.placeID))
                    .lineLimit(1)
                Spacer(minLength: Design.small)
                Text(DurationFormat.readable(total.totalSeconds))
                    .monospacedDigit()
            }
            ProgressView(value: share)
                .progressViewStyle(.linear)
                .tint(PlaceColor.color(for: total.placeID))
                .accessibilityHidden(true)
            Text("%\(Int((share * 100).rounded())) · \(total.sessionCount) oturum")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, Design.tight)
    }
}

#Preview {
    StatisticsSettingsView(
        coordinator: AppCoordinator(directory: .temporaryDirectory),
        navigation: StatsNavigation()
    )
        .frame(width: Design.settingsPaneWidth, height: Design.settingsHeight)
}
