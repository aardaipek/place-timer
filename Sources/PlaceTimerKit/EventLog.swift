import Foundation
import PlaceTimerCore

/// Olay günlüğü dosyası. Yazma hataları yutulur: günlük teşhis içindir,
/// yazılamaması uygulamayı durdurmamalı.
@MainActor
public final class EventLog {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func record(_ message: String, at date: Date = Date()) {
        let data = Data(EventLogFormat.line(message, at: date).utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Açılışta bir kez: 14 günden eski satırları atar.
    public func prune(now: Date = Date()) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        try? Data(EventLogFormat.pruned(text, now: now).utf8).write(to: url, options: .atomic)
    }

    public func erase() {
        try? FileManager.default.removeItem(at: url)
    }
}
