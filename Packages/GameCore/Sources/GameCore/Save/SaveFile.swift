import Foundation

/// Saves and loads the game as versioned JSON.
///
/// When the save format changes: bump `currentVersion` and add a migration from the
/// old version to `migrations`. Migrations work on the raw JSON, so old saves never
/// need the old Swift types to still exist.
public enum SaveFile {
    public static let currentVersion = 1

    public enum SaveError: Error, Equatable, CustomStringConvertible {
        case notASave
        case fromNewerVersion(Int)
        case missingMigration(from: Int)

        public var description: String {
            switch self {
            case .notASave: "That file isn't a Golf: The Empire save."
            case .fromNewerVersion(let v): "This save (version \(v)) comes from a newer version of the game. Update the app to load it."
            case .missingMigration(let v): "No way to upgrade a version \(v) save. This is a bug."
            }
        }
    }

    /// Upgrades a raw save from `version` to `version + 1`. Add a case for each new version.
    static func migrate(_ object: [String: Any], from version: Int) throws -> [String: Any] {
        switch version {
        default: throw SaveError.missingMigration(from: version)
        }
    }

    private struct Envelope: Codable {
        let version: Int
        let savedAt: String
        let state: GameState
    }

    private struct VersionOnly: Decodable {
        let version: Int
    }

    public static func encode(_ state: GameState, savedAt: Date = Date()) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let stamp = ISO8601DateFormatter().string(from: savedAt)
        return try encoder.encode(Envelope(version: currentVersion, savedAt: stamp, state: state))
    }

    public static func decode(_ data: Data) throws -> GameState {
        guard let version = try? JSONDecoder().decode(VersionOnly.self, from: data).version else {
            throw SaveError.notASave
        }
        if version > currentVersion { throw SaveError.fromNewerVersion(version) }
        var json = data
        if version < currentVersion {
            guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SaveError.notASave
            }
            for v in version..<currentVersion {
                object = try migrate(object, from: v)
                object["version"] = v + 1
            }
            json = try JSONSerialization.data(withJSONObject: object)
        }
        return try JSONDecoder().decode(Envelope.self, from: json).state
    }

    /// Writes atomically, so a crash mid save never leaves a half written file.
    public static func write(_ state: GameState, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(state).write(to: url, options: .atomic)
    }

    public static func read(from url: URL) throws -> GameState {
        try decode(Data(contentsOf: url))
    }
}
