public import Foundation

public protocol ReplayStore: Sendable {
    func record(for key: ReplayKey) async throws -> ReplayRecord?
}

public protocol ReplayStoreWriter: Sendable {
    func write(_ record: ReplayRecord, for key: ReplayKey) async throws
}

public struct MemoryReplayStore: ReplayStore {
    public var records: [ReplayKey: ReplayRecord]

    public init(records: [ReplayKey: ReplayRecord]) {
        self.records = records
    }

    public func record(for key: ReplayKey) async throws -> ReplayRecord? {
        records[key]
    }
}

public protocol ReplayFileNameStrategy: Sendable {
    func fileName(for key: ReplayKey) -> String
}

public struct SafeReplayFileNameStrategy: ReplayFileNameStrategy {
    public var fileExtension: String

    public init(fileExtension: String = "json") {
        self.fileExtension = fileExtension
    }

    public func fileName(for key: ReplayKey) -> String {
        let parts = [
            "operation-\(Self.encodeComponent(key.operationID))",
            key.scenario.map { "scenario-\(Self.encodeComponent($0))" },
            key.requestFingerprint.map { "fingerprint-\(Self.encodeComponent($0))" },
        ].compactMap { $0 }

        let name = parts.joined(separator: ".")
        let encodedExtension = Self.encodeComponent(fileExtension)
        return encodedExtension.isEmpty ? name : "\(name).\(encodedExtension)"
    }

    private static func encodeComponent(_ value: String) -> String {
        value.utf8.map { byte -> String in
            switch byte {
            case 45, 48...57, 65...90, 95, 97...122:
                return String(UnicodeScalar(byte))
            default:
                return String(format: "%%%02X", byte)
            }
        }.joined()
    }
}

public struct FileReplayStore: ReplayStore, ReplayStoreWriter {
    public var rootDirectory: URL
    public var fileNameStrategy: any ReplayFileNameStrategy

    public init(
        rootDirectory: URL,
        fileNameStrategy: any ReplayFileNameStrategy = SafeReplayFileNameStrategy()
    ) {
        self.rootDirectory = rootDirectory
        self.fileNameStrategy = fileNameStrategy
    }

    public func record(for key: ReplayKey) async throws -> ReplayRecord? {
        let url = url(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try await Task.detached {
                try Data(contentsOf: url)
            }.value
            return try JSONDecoder().decode(ReplayRecord.self, from: data)
        } catch {
            throw ReplayError.invalidRecord(key, String(describing: error))
        }
    }

    public func write(_ record: ReplayRecord, for key: ReplayKey) async throws {
        do {
            try FileManager.default.createDirectory(
                at: rootDirectory,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(record)
            let url = url(for: key)
            try await Task.detached {
                try data.write(to: url, options: [.atomic])
            }.value
        } catch {
            throw ReplayError.cannotWriteRecord(key, String(describing: error))
        }
    }

    public func url(for key: ReplayKey) -> URL {
        rootDirectory.appendingPathComponent(fileNameStrategy.fileName(for: key))
    }
}

public struct ClosureReplayStore: ReplayStore {
    private let lookup: @Sendable (ReplayKey) async throws -> ReplayRecord?

    public init(_ lookup: @escaping @Sendable (ReplayKey) async throws -> ReplayRecord?) {
        self.lookup = lookup
    }

    public func record(for key: ReplayKey) async throws -> ReplayRecord? {
        try await lookup(key)
    }
}

public enum ReplayError: Error, Equatable, Sendable {
    case missingRecord(ReplayKey)
    case invalidRecord(ReplayKey, String)
    case cannotWriteRecord(ReplayKey, String)
    case invalidFingerprintHeaderName(String)
}
