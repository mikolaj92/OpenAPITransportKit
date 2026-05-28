public import OpenAPITransportKitCore

public struct ReplayKey: Hashable, Codable, Sendable {
    public var operationID: String
    public var requestFingerprint: String?
    public var scenario: String?

    public init(
        operationID: String,
        requestFingerprint: String? = nil,
        scenario: String? = nil
    ) {
        self.operationID = operationID
        self.requestFingerprint = requestFingerprint
        self.scenario = scenario
    }
}

public protocol ReplayKeyStrategy: Sendable {
    func key(for context: TransportRequestContext) async throws -> ReplayKey
}

public struct OperationIDReplayKeyStrategy: ReplayKeyStrategy {
    public init() {}

    public func key(for context: TransportRequestContext) async throws -> ReplayKey {
        ReplayKey(operationID: context.operationID)
    }
}

public struct ClosureReplayKeyStrategy: ReplayKeyStrategy {
    private let makeKey: @Sendable (TransportRequestContext) async throws -> ReplayKey

    public init(_ makeKey: @escaping @Sendable (TransportRequestContext) async throws -> ReplayKey) {
        self.makeKey = makeKey
    }

    public func key(for context: TransportRequestContext) async throws -> ReplayKey {
        try await makeKey(context)
    }
}

