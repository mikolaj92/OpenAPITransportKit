public import OpenAPITransportKitCore

public struct StatefulProviderOutput<State: Sendable>: Sendable {
    public var state: State
    public var response: TransportResponse

    public init(state: State, response: TransportResponse) {
        self.state = state
        self.response = response
    }
}

public protocol StatefulResponseHandler: Sendable {
    associatedtype State: Sendable

    func response(
        for context: TransportRequestContext,
        state: State
    ) async throws -> StatefulProviderOutput<State>
}

public struct ClosureStatefulResponseHandler<State: Sendable>: StatefulResponseHandler {
    private let respond: @Sendable (TransportRequestContext, State) async throws -> StatefulProviderOutput<State>

    public init(
        _ respond: @escaping @Sendable (TransportRequestContext, State) async throws -> StatefulProviderOutput<State>
    ) {
        self.respond = respond
    }

    public func response(
        for context: TransportRequestContext,
        state: State
    ) async throws -> StatefulProviderOutput<State> {
        try await respond(context, state)
    }
}

public actor StatefulResponseProvider<Handler: StatefulResponseHandler>: ResponseProvider {
    public typealias State = Handler.State

    private var state: State
    private let handler: Handler
    private var previousResponseTask: Task<Void, Never>?

    public init(initialState: State, handler: Handler) {
        self.state = initialState
        self.handler = handler
    }

    public func response(for context: TransportRequestContext) async throws -> TransportResponse {
        let previousResponseTask = self.previousResponseTask
        let responseTask = Task {
            await previousResponseTask?.value
            try Task.checkCancellation()
            return try await self.serializedResponse(for: context)
        }
        self.previousResponseTask = Task {
            _ = try? await responseTask.value
        }
        return try await withTaskCancellationHandler {
            try await responseTask.value
        } onCancel: {
            responseTask.cancel()
        }
    }

    private func serializedResponse(for context: TransportRequestContext) async throws -> TransportResponse {
        let output = try await handler.response(for: context, state: state)
        state = output.state
        return output.response
    }

    public func currentState() -> State {
        state
    }
}

public typealias StatefulTransport<State: Sendable> =
    ProviderTransport<StatefulResponseProvider<ClosureStatefulResponseHandler<State>>>

public typealias StatefulProviderTransport<Handler: StatefulResponseHandler> =
    ProviderTransport<StatefulResponseProvider<Handler>>

public extension ProviderTransport {
    init<Handler: StatefulResponseHandler>(
        initialState: Handler.State,
        handler: Handler
    ) where Provider == StatefulResponseProvider<Handler> {
        self.init(
            provider: StatefulResponseProvider(
                initialState: initialState,
                handler: handler
            )
        )
    }

    init<State: Sendable>(
        initialState: State,
        _ respond: @escaping @Sendable (TransportRequestContext, State) async throws -> StatefulProviderOutput<State>
    ) where Provider == StatefulResponseProvider<ClosureStatefulResponseHandler<State>> {
        self.init(
            initialState: initialState,
            handler: ClosureStatefulResponseHandler(respond)
        )
    }
}
