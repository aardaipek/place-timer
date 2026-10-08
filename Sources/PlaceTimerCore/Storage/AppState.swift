import Foundation

/// `state.json` içeriği: açık oturum ve son yaşam belirtisi.
///
/// `lastHeartbeatAt`, uygulama çökse veya kapatılsa bile "ne zamandır ayakta
/// değil" sorusunu cevaplar. Yeniden açılışta bu aradaki boşluk uykuyla aynı
/// kuralla değerlendirilir; yoksa gece kapatılan uygulama sabah "15 saattir
/// buradasın" derdi.
public struct AppState: Codable, Sendable, Equatable {
    public var currentSession: Session?
    public var lastHeartbeatAt: Date?
    /// Motorun son kapanan oturumları; aynı yere dönüşte geri açma için.
    public var recentlyEnded: [Session]

    public init(
        currentSession: Session? = nil,
        lastHeartbeatAt: Date? = nil,
        recentlyEnded: [Session] = []
    ) {
        self.currentSession = currentSession
        self.lastHeartbeatAt = lastHeartbeatAt
        self.recentlyEnded = recentlyEnded
    }

    /// 1.0'ın dosyasında `recentlyEnded` yok.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            currentSession: try container.decodeIfPresent(Session.self, forKey: .currentSession),
            lastHeartbeatAt: try container.decodeIfPresent(Date.self, forKey: .lastHeartbeatAt),
            recentlyEnded: try container.decodeIfPresent([Session].self, forKey: .recentlyEnded)
                ?? []
        )
    }
}

extension SessionEngine {
    /// Diskteki durumdan motoru kurar.
    ///
    /// Uygulamanın kapalı geçirdiği süre, uyku ile aynı eşiğe tabidir: kısaysa
    /// oturum sürer, uzunsa son yaşam belirtisinde kapanıp yenisi açılır.
    public static func restored(
        from state: AppState,
        configuration: EngineConfiguration = EngineConfiguration(),
        now: Date
    ) -> (engine: SessionEngine, effects: [SessionEffect]) {
        var engine = SessionEngine(
            configuration: configuration,
            restoring: state.currentSession,
            recentlyEnded: state.recentlyEnded
        )

        guard state.currentSession != nil, let heartbeat = state.lastHeartbeatAt else {
            let effects = engine.handle(.wake, at: now)
            return (engine, effects)
        }

        var effects = engine.handle(.sleep, at: heartbeat)
        effects += engine.handle(.wake, at: now)
        return (engine, effects)
    }
}
