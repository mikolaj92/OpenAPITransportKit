public import Foundation
public import HTTPTypes
public import OpenAPIRuntime
import OpenAPITransportKitCore

public enum RecordingFailureStrategy: Sendable, Equatable {
    case `throw`
    case ignore
}

public struct RecordingClientMiddleware: ClientMiddleware {
    public var writer: any ReplayStoreWriter
    public var keyStrategy: any ReplayKeyStrategy
    public var recordedAt: @Sendable () -> Date
    public var maximumRequestBodyBytes: Int
    public var maximumResponseBodyBytes: Int
    public var failureStrategy: RecordingFailureStrategy

    public init(
        writer: any ReplayStoreWriter,
        keyStrategy: any ReplayKeyStrategy = OperationIDReplayKeyStrategy(),
        recordedAt: @escaping @Sendable () -> Date = Date.init,
        maximumRequestBodyBytes: Int = 1024 * 1024,
        maximumResponseBodyBytes: Int = 10 * 1024 * 1024,
        failureStrategy: RecordingFailureStrategy = .throw
    ) {
        self.writer = writer
        self.keyStrategy = keyStrategy
        self.recordedAt = recordedAt
        self.maximumRequestBodyBytes = maximumRequestBodyBytes
        self.maximumResponseBodyBytes = maximumResponseBodyBytes
        self.failureStrategy = failureStrategy
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let bufferedRequestBody = try await BufferedBody(body, maximumBytes: maximumRequestBodyBytes)
        let context = TransportRequestContext(
            request: request,
            body: bufferedRequestBody.makeBody(),
            baseURL: baseURL,
            operationID: operationID
        )

        let key: ReplayKey?
        do {
            key = try await keyStrategy.key(for: context)
        } catch {
            switch failureStrategy {
            case .throw:
                throw error
            case .ignore:
                key = nil
            }
        }

        let (response, responseBody) = try await next(request, bufferedRequestBody.makeBody(), baseURL)
        let bufferedResponseBody = try await BufferedBody(responseBody, maximumBytes: maximumResponseBodyBytes)

        if let key {
            do {
                try await writer.write(
                    ReplayRecord(
                        response: response,
                        body: bufferedResponseBody.data,
                        recordedAt: recordedAt()
                    ),
                    for: key
                )
            } catch {
                if failureStrategy == .throw {
                    throw error
                }
            }
        }

        return (response, bufferedResponseBody.makeBody())
    }
}

private struct BufferedBody {
    var data: Data?

    init(_ body: HTTPBody?, maximumBytes: Int) async throws {
        if let body {
            self.data = try await Data(collecting: body, upTo: maximumBytes)
        } else {
            self.data = nil
        }
    }

    func makeBody() -> HTTPBody? {
        data.map { HTTPBody($0) }
    }
}
