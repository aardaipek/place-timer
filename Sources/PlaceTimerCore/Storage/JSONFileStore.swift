import Foundation

/// Tek bir JSON dosyasını okuyup yazan ince sarmalayıcı.
///
/// Yazım atomiktir: veri önce geçici bir dosyaya yazılır, sonra yerine
/// taşınır. Böylece yazma sırasında kesinti olursa yarım dosya kalmaz.
public struct JSONFileStore<Value: Codable & Sendable>: Sendable {
    public let url: URL

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public init(url: URL) {
        self.url = url
    }

    /// Dosya yoksa `nil` döner — ilk çalıştırma hata değildir.
    public func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return nil }
        return try Self.decoder.decode(Value.self, from: data)
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}

extension URL {
    /// `~/Library/Application Support/PlaceTimer/`
    public static func placeTimerSupportDirectory(
        fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager
            .url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("PlaceTimer", isDirectory: true)
    }
}
