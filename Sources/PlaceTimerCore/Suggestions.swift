import Foundation

/// Uygulamanın kendi bulduğu düzeltme adayı. Kullanıcı tek tıkla onaylar ya
/// da reddeder; geçmişe dokunmak her zaman onayla olur.
public enum Suggestion: Sendable, Equatable, Identifiable {
    /// İki kayıt aynı yer gibi görünüyor. `keep` eski olan; birleştirmede kalır.
    case samePlace(keep: UUID, merge: UUID)
    /// Aynı yerde, arası kısa iki ardışık oturum.
    case splitSession(first: UUID, second: UUID)
    /// Hiçbir şey anlatmayan, çok kısa kapanmış oturum.
    case emptySession(UUID)

    /// Kararlı kimlik: reddedilenler bununla saklanır. Yer çiftinde sıra
    /// önemsiz; hangisinin eski olduğu ileride değişse de aynı öneridir.
    public var id: String {
        switch self {
        case .samePlace(let a, let b):
            "yer:" + [a.uuidString, b.uuidString].sorted().joined(separator: ":")
        case .splitSession(let a, let b):
            "bolunme:\(a.uuidString):\(b.uuidString)"
        case .emptySession(let a):
            "bos:\(a.uuidString)"
        }
    }
}

/// `suggestions.json` içeriği.
public struct SuggestionState: Codable, Sendable, Equatable {
    public var dismissed: Set<String>
    /// Onaylanan bölünme önerisi sayısı. Kullanıcı aynı türden aralığı tekrar
    /// tekrar birleştiriyorsa eşiği büyütmeyi önermenin dayanağı.
    public var acceptedSplits: Int

    public init(dismissed: Set<String> = [], acceptedSplits: Int = 0) {
        self.dismissed = dismissed
        self.acceptedSplits = acceptedSplits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            dismissed: try container.decodeIfPresent(Set<String>.self, forKey: .dismissed) ?? [],
            acceptedSplits: try container.decodeIfPresent(Int.self, forKey: .acceptedSplits) ?? 0
        )
    }
}

public enum SuggestionRules {
    public static let samePlaceDistance: Double = 150
    public static let splitGapMultiplier: Double = 3
    public static let emptySessionLimit: TimeInterval = 120
}

/// Öneriler: önce yerler (en çok bölünmeye onlar yol açar), sonra oturumlar
/// en yenisi başta.
public func suggestions(
    places: [Place],
    sessions: [Session],
    dismissed: Set<String>,
    gapThreshold: TimeInterval
) -> [Suggestion] {
    var result: [Suggestion] = samePlaceSuggestions(places)

    let empties = sessions.filter {
        guard let end = $0.endedAt else { return false }
        return end.timeIntervalSince($0.startedAt) < SuggestionRules.emptySessionLimit
    }
    let emptyIDs = Set(empties.map(\.id))

    var sessionSuggestions: [(Date, Suggestion)] = empties.map { ($0.startedAt, .emptySession($0.id)) }

    let ordered = sessions
        .filter { !emptyIDs.contains($0.id) }
        .sorted { $0.startedAt < $1.startedAt }
    for (first, second) in zip(ordered, ordered.dropFirst()) {
        guard
            let placeID = first.placeID, second.placeID == placeID,
            let firstEnd = first.endedAt
        else { continue }
        let gap = second.startedAt.timeIntervalSince(firstEnd)
        guard gap >= 0, gap < gapThreshold * SuggestionRules.splitGapMultiplier else { continue }
        sessionSuggestions.append((second.startedAt, .splitSession(first: first.id, second: second.id)))
    }

    result += sessionSuggestions.sorted { $0.0 > $1.0 }.map(\.1)
    return result.filter { !dismissed.contains($0.id) }
}

private func samePlaceSuggestions(_ places: [Place]) -> [Suggestion] {
    let ordered = places.sorted { $0.createdAt < $1.createdAt }
    var result: [Suggestion] = []
    var merged: Set<UUID> = []

    for (index, keep) in ordered.enumerated() where !merged.contains(keep.id) {
        for candidate in ordered.dropFirst(index + 1) where !merged.contains(candidate.id) {
            guard isSamePlace(keep, candidate) else { continue }
            result.append(.samePlace(keep: keep.id, merge: candidate.id))
            merged.insert(candidate.id)
        }
    }
    return result
}

private func isSamePlace(_ a: Place, _ b: Place) -> Bool {
    if normalized(a.displayName) == normalized(b.displayName) { return true }
    guard let ca = a.coordinate, let cb = b.coordinate else { return false }
    return ca.distance(to: cb) <= SuggestionRules.samePlaceDistance
}

private func normalized(_ name: String) -> String {
    // Noktasız "ı" aksan sayılmıyor; katlama onu "i"ye indirmiyor.
    name.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "ı", with: "i")
        .replacingOccurrences(of: "İ", with: "i")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
}
