public import Foundation
public import HTTPTypes
public import OpenAPIRuntime

public struct MultiplexingTransport<Selector: TransportSelector>: ClientTransport {
    public var selector: Selector

    public init(selector: Selector) {
        self.selector = selector
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
        let transport = try await selector.transport(for: context)
        return try await transport.send(request, body: body, baseURL: baseURL, operationID: operationID)
    }
}
