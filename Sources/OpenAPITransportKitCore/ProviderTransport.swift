public import Foundation
public import HTTPTypes
public import OpenAPIRuntime

public struct ProviderTransport<Provider: ResponseProvider>: ClientTransport {
    public var provider: Provider

    public init(provider: Provider) {
        self.provider = provider
    }

    public func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let context = TransportRequestContext(
            request: request,
            body: body,
            baseURL: baseURL,
            operationID: operationID
        )
        let output = try await provider.response(for: context)
        return (output.response, output.body)
    }
}

public typealias AnyProviderTransport = ProviderTransport<AnyResponseProvider>
