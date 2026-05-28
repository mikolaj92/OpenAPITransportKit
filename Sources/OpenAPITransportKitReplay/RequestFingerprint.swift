import Foundation
import HTTPTypes
public import OpenAPITransportKitCore
import OpenAPIRuntime

public protocol RequestFingerprinter: Sendable {
    /// Returns a stable, non-cryptographic identifier for the request shape.
    ///
    /// `HTTPBody` is a single-pass async sequence. Fingerprinters that include
    /// the body consume `context.body`; use them with `RecordingClientMiddleware`
    /// or another buffering layer when the live request still needs the body.
    func fingerprint(for context: TransportRequestContext) async throws -> String
}

public struct StableRequestFingerprinter: RequestFingerprinter {
    public var includedHeaderNames: [String]
    /// Includes the request body bytes in the fingerprint.
    ///
    /// This consumes `TransportRequestContext.body`. `RecordingClientMiddleware`
    /// buffers the body before computing a key, so it can safely forward a fresh
    /// body to the wrapped transport. Custom transports should do the same.
    public var includesBody: Bool
    public var maximumBodyBytes: Int

    public init(
        includedHeaderNames: [String] = [],
        includesBody: Bool = false,
        maximumBodyBytes: Int = 1024 * 1024
    ) {
        self.includedHeaderNames = includedHeaderNames.map { $0.lowercased() }.sorted()
        self.includesBody = includesBody
        self.maximumBodyBytes = maximumBodyBytes
    }

    public func fingerprint(for context: TransportRequestContext) async throws -> String {
        var hasher = FNV1a64()
        hasher.update("operation=\(context.operationID)\n")
        hasher.update("method=\(context.request.method.rawValue)\n")
        hasher.update("scheme=\(context.request.scheme ?? "")\n")
        hasher.update("authority=\(context.request.authority ?? "")\n")
        hasher.update("path=\(context.request.path ?? "")\n")

        for headerName in includedHeaderNames {
            guard let name = HTTPField.Name(headerName) else {
                throw ReplayError.invalidFingerprintHeaderName(headerName)
            }
            hasher.update("header:\(headerName)=\(context.request.headerFields[name] ?? "")\n")
        }

        if includesBody, let body = context.body {
            let bytes = try await [UInt8](collecting: body, upTo: maximumBodyBytes)
            hasher.update("body=")
            hasher.update(bytes)
        }

        return hasher.hexDigest
    }
}

public struct FingerprintedReplayKeyStrategy: ReplayKeyStrategy {
    public var fingerprinter: any RequestFingerprinter
    public var scenario: String?

    public init(
        fingerprinter: any RequestFingerprinter = StableRequestFingerprinter(),
        scenario: String? = nil
    ) {
        self.fingerprinter = fingerprinter
        self.scenario = scenario
    }

    public func key(for context: TransportRequestContext) async throws -> ReplayKey {
        let fingerprint = try await fingerprinter.fingerprint(for: context)
        return ReplayKey(
            operationID: context.operationID,
            requestFingerprint: fingerprint,
            scenario: scenario
        )
    }
}

private struct FNV1a64 {
    private var value: UInt64 = 0xcbf29ce484222325

    mutating func update(_ string: String) {
        update(string.utf8)
    }

    mutating func update(_ bytes: some Sequence<UInt8>) {
        for byte in bytes {
            value ^= UInt64(byte)
            value = value &* 0x100000001b3
        }
    }

    var hexDigest: String {
        String(format: "%016llx", value)
    }
}
