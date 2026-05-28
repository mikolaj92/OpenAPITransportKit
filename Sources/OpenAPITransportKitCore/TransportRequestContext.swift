public import Foundation
public import HTTPTypes
public import OpenAPIRuntime

public struct TransportRequestContext: Sendable {
    public let request: HTTPRequest
    public let body: HTTPBody?
    public let baseURL: URL
    public let operationID: String

    public init(
        request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) {
        self.request = request
        self.body = body
        self.baseURL = baseURL
        self.operationID = operationID
    }
}
