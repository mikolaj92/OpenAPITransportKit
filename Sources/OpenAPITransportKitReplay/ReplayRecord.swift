public import Foundation
public import HTTPTypes
public import OpenAPITransportKitCore
import OpenAPIRuntime

public struct ReplayRecord: Codable, Sendable {
    public var response: HTTPResponse
    public var body: Data?
    public var recordedAt: Date?

    public init(
        response: HTTPResponse,
        body: Data? = nil,
        recordedAt: Date? = nil
    ) {
        self.response = response
        self.body = body
        self.recordedAt = recordedAt
    }

    public func transportResponse() -> TransportResponse {
        TransportResponse(
            response: response,
            body: body.map { HTTPBody($0) }
        )
    }
}
