public import Foundation

public protocol FixtureLoader: Sendable {
    func load(_ reference: FixtureReference) async throws -> FixturePayload
}

public protocol FixtureMetadataReferenceResolver: Sendable {
    func metadataReference(for reference: FixtureReference) -> FixtureReference
}

public struct DotSeparatedFixtureMetadataReferenceResolver: FixtureMetadataReferenceResolver {
    public var fileExtension: String

    public init(fileExtension: String = "json") {
        self.fileExtension = fileExtension
    }

    public func metadataReference(for reference: FixtureReference) -> FixtureReference {
        let suffix = ".\(fileExtension)"
        if reference.rawValue.hasSuffix(suffix) {
            let base = String(reference.rawValue.dropLast(suffix.count))
            return FixtureReference(rawValue: "\(base).meta.\(fileExtension)")
        }
        return FixtureReference(rawValue: "\(reference.rawValue).meta.\(fileExtension)")
    }
}

public protocol FixtureMetadataDecoder: Sendable {
    func decodeMetadata(from data: Data, reference: FixtureReference) throws -> FixtureResponseMetadata
}

public struct JSONFixtureMetadataDecoder: FixtureMetadataDecoder {
    public var makeDecoder: @Sendable () -> JSONDecoder

    public init(makeDecoder: @escaping @Sendable () -> JSONDecoder = { JSONDecoder() }) {
        self.makeDecoder = makeDecoder
    }

    public init(decoder: JSONDecoder) {
        self.makeDecoder = { decoder }
    }

    public func decodeMetadata(from data: Data, reference: FixtureReference) throws -> FixtureResponseMetadata {
        do {
            return try makeDecoder().decode(FixtureResponseMetadataDocument.self, from: data).metadata()
        } catch let error as FixtureError {
            throw error
        } catch {
            throw FixtureError.invalidMetadata(reference, String(describing: error))
        }
    }
}

public protocol FixtureDataLoader: Sendable {
    func loadData(_ reference: FixtureReference) async throws -> Data
    func loadOptionalData(_ reference: FixtureReference) async throws -> Data?
}

public extension FixtureDataLoader {
    func loadOptionalData(_ reference: FixtureReference) async throws -> Data? {
        do {
            return try await loadData(reference)
        } catch FixtureError.missingFixture {
            return nil
        }
    }
}

public struct MemoryFixtureLoader: FixtureLoader {
    public var fixtures: [FixtureReference: FixturePayload]

    public init(fixtures: [FixtureReference: FixturePayload]) {
        self.fixtures = fixtures
    }

    public func load(_ reference: FixtureReference) async throws -> FixturePayload {
        guard let payload = fixtures[reference] else {
            throw FixtureError.missingFixture(reference)
        }
        return payload
    }
}

public struct PayloadFixtureLoader<DataLoader: FixtureDataLoader>: FixtureLoader {
    public var dataLoader: DataLoader
    public var metadataReferenceResolver: any FixtureMetadataReferenceResolver
    public var metadataDecoder: any FixtureMetadataDecoder

    public init(
        dataLoader: DataLoader,
        metadataReferenceResolver: any FixtureMetadataReferenceResolver = DotSeparatedFixtureMetadataReferenceResolver(),
        metadataDecoder: any FixtureMetadataDecoder = JSONFixtureMetadataDecoder()
    ) {
        self.dataLoader = dataLoader
        self.metadataReferenceResolver = metadataReferenceResolver
        self.metadataDecoder = metadataDecoder
    }

    public func load(_ reference: FixtureReference) async throws -> FixturePayload {
        let data = try await dataLoader.loadData(reference)
        let metadataReference = metadataReferenceResolver.metadataReference(for: reference)
        let metadata = try await dataLoader.loadOptionalData(metadataReference).map {
            try metadataDecoder.decodeMetadata(from: $0, reference: metadataReference)
        }
        return FixturePayload(data: data, metadata: metadata)
    }
}

public struct FileSystemFixtureDataLoader: FixtureDataLoader {
    public var rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    public func loadData(_ reference: FixtureReference) async throws -> Data {
        let url = rootDirectory.appendingPathComponent(reference.rawValue)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureError.missingFixture(reference)
        }
        return try await Task.detached {
            try Data(contentsOf: url)
        }.value
    }
}

public typealias FileSystemFixtureLoader = PayloadFixtureLoader<FileSystemFixtureDataLoader>

public extension PayloadFixtureLoader where DataLoader == FileSystemFixtureDataLoader {
    init(
        rootDirectory: URL,
        metadataReferenceResolver: any FixtureMetadataReferenceResolver = DotSeparatedFixtureMetadataReferenceResolver(),
        metadataDecoder: any FixtureMetadataDecoder = JSONFixtureMetadataDecoder()
    ) {
        self.init(
            dataLoader: FileSystemFixtureDataLoader(rootDirectory: rootDirectory),
            metadataReferenceResolver: metadataReferenceResolver,
            metadataDecoder: metadataDecoder
        )
    }
}

/// Loads fixture bytes from a `Bundle` resource lookup.
///
/// Lookup is fail-closed and single-path: resources are resolved only with the
/// configured `subdirectory` (or bundle root when `subdirectory` is `nil`).
/// There is no silent downgrade from a missing subdirectory to root resources.
public struct BundleFixtureDataLoader: FixtureDataLoader {
    public var bundle: Bundle
    public var subdirectory: String?

    public init(
        bundle: Bundle,
        subdirectory: String? = nil
    ) {
        self.bundle = bundle
        self.subdirectory = subdirectory
    }

    public func loadData(_ reference: FixtureReference) async throws -> Data {
        let url = bundle.url(
            forResource: reference.resourceName,
            withExtension: reference.resourceExtension,
            subdirectory: subdirectory
        )
        guard let url else {
            throw FixtureError.missingFixture(reference)
        }
        return try await Task.detached {
            try Data(contentsOf: url)
        }.value
    }
}

public typealias BundleFixtureLoader = PayloadFixtureLoader<BundleFixtureDataLoader>

public extension PayloadFixtureLoader where DataLoader == BundleFixtureDataLoader {
    init(
        bundle: Bundle,
        subdirectory: String? = nil,
        metadataReferenceResolver: any FixtureMetadataReferenceResolver = DotSeparatedFixtureMetadataReferenceResolver(),
        metadataDecoder: any FixtureMetadataDecoder = JSONFixtureMetadataDecoder()
    ) {
        self.init(
            dataLoader: BundleFixtureDataLoader(
                bundle: bundle,
                subdirectory: subdirectory
            ),
            metadataReferenceResolver: metadataReferenceResolver,
            metadataDecoder: metadataDecoder
        )
    }
}

public struct ClosureFixtureLoader: FixtureLoader {
    private let loadPayload: @Sendable (FixtureReference) async throws -> FixturePayload

    public init(_ loadPayload: @escaping @Sendable (FixtureReference) async throws -> FixturePayload) {
        self.loadPayload = loadPayload
    }

    public func load(_ reference: FixtureReference) async throws -> FixturePayload {
        try await loadPayload(reference)
    }
}

public enum FixtureError: Error, Equatable, Sendable {
    case missingFixture(FixtureReference)
    case invalidHeaderName(String)
    case invalidMetadata(FixtureReference, String)
}

private extension FixtureReference {
    var resourceName: String {
        NSString(string: rawValue).deletingPathExtension
    }

    var resourceExtension: String? {
        let pathExtension = NSString(string: rawValue).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension
    }
}
