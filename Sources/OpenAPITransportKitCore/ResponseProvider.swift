public protocol ResponseProvider: Sendable {
    func response(for context: TransportRequestContext) async throws -> TransportResponse
}

public struct AnyResponseProvider: ResponseProvider {
    private let respond: @Sendable (TransportRequestContext) async throws -> TransportResponse

    public init(_ respond: @escaping @Sendable (TransportRequestContext) async throws -> TransportResponse) {
        self.respond = respond
    }

    public init<Provider: ResponseProvider>(_ provider: Provider) {
        self.respond = { context in
            try await provider.response(for: context)
        }
    }

    public func response(for context: TransportRequestContext) async throws -> TransportResponse {
        try await respond(context)
    }
}

