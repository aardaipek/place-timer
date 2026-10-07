import PlaceTimerCore

/// Bir önerinin kullanıcıya söylediği cümle. Panel kartı ve istatistik
/// sayfası aynı metni gösterir.
struct SuggestionText {
    let title: String
    let detail: String
    let action: String

    @MainActor
    static func make(_ suggestion: Suggestion, coordinator: AppCoordinator) -> SuggestionText {
        switch suggestion {
        case .samePlace(let keep, let merge):
            let a = coordinator.placeName(for: keep)
            let b = coordinator.placeName(for: merge)
            return SuggestionText(
                title: a == b ? "İki ayrı “\(a)” kaydı var" : "“\(b)” ile “\(a)” aynı yer mi?",
                detail: "Birleştirirsem ağları ve geçmişteki oturumları tek yerde toplanır.",
                action: "Birleştir"
            )
        case .splitSession(let first, let second):
            let ilk = coordinator.session(id: first)
            let ikinci = coordinator.session(id: second)
            let yer = coordinator.placeName(for: ilk?.placeID)
            let bitis = ilk?.endedAt.map(DurationFormat.time) ?? "?"
            let baslangic = ikinci.map { DurationFormat.time($0.startedAt) } ?? "?"
            return SuggestionText(
                title: "\(yer)'daki oturum bölünmüş görünüyor",
                detail: "\(bitis)'da biten ve \(baslangic)'da başlayan iki oturum tek oturum olabilir.",
                action: "Birleştir"
            )
        case .emptySession(let id):
            let oturum = coordinator.session(id: id)
            let yer = coordinator.placeName(for: oturum?.placeID)
            let saat = oturum.map { DurationFormat.time($0.startedAt) } ?? "?"
            return SuggestionText(
                title: "Boş bir oturum var",
                detail: "\(yer)'da \(saat)'da açılıp 2 dakika dolmadan kapanmış.",
                action: "Sil"
            )
        }
    }
}
