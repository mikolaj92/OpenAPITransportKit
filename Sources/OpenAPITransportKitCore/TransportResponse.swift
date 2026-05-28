public import HTTPTypes
public import OpenAPIRuntime

public struct TransportResponse: Sendable {
    public var response: HTTPResponse
    public var body: HTTPBody?

    public init(response: HTTPResponse, body: HTTPBody? = nil) {
        self.response = response
        self.body = body
    }

    public init(
        status: HTTPResponse.Status,
        headerFields: HTTPFields = [:],
        body: HTTPBody? = nil
    ) {
        self.response = HTTPResponse(status: status, headerFields: headerFields)
        self.body = body
    }
}
