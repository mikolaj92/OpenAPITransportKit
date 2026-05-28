public import OpenAPITransportKitCore

public struct ClosureResponseProvider: ResponseProvider {
    private let respond: @Sendable (TransportRequestContext) async throws -> TransportResponse

    public init(_ respond: @escaping @Sendable (TransportRequestContext) async throws -> TransportResponse) {
        self.respond = respond
    }

    public func response(for context: TransportRequestContext) async throws -> TransportResponse {
        try await respond(context)
    }
}

public typealias DynamicTransport = ProviderTransport<ClosureResponseProvider>

