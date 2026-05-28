public import OpenAPITransportKitCore

public struct ReplayResponseProvider: ResponseProvider {
    public var store: any ReplayStore
    public var keyStrategy: any ReplayKeyStrategy

    public init(
        store: any ReplayStore,
        keyStrategy: any ReplayKeyStrategy = OperationIDReplayKeyStrategy()
    ) {
        self.store = store
        self.keyStrategy = keyStrategy
    }

    public func response(for context: TransportRequestContext) async throws -> TransportResponse {
        let key = try await keyStrategy.key(for: context)
        guard let record = try await store.record(for: key) else {
            throw ReplayError.missingRecord(key)
        }
        return record.transportResponse()
    }
}

