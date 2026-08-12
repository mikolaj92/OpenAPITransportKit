public import OpenAPIRuntime

public protocol TransportSelector: Sendable {
    func transport(for context: TransportRequestContext) async throws -> any ClientTransport
}

public struct ClosureTransportSelector: TransportSelector {
    private let select: @Sendable (TransportRequestContext) async throws -> any ClientTransport

    public init(_ select: @escaping @Sendable (TransportRequestContext) async throws -> any ClientTransport) {
        self.select = select
    }

    public func transport(for context: TransportRequestContext) async throws -> any ClientTransport {
        try await select(context)
    }
}

public enum TransportSource: Hashable, Sendable {
    case live
    case fixtures
    case replay
    case dynamic
    case stateful
}

public protocol TransportSourceProvider: Sendable {
    func source(for context: TransportRequestContext) async throws -> TransportSource
}

public struct ClosureTransportSourceProvider: TransportSourceProvider {
    private let source: @Sendable (TransportRequestContext) async throws -> TransportSource

    public init(_ source: @escaping @Sendable (TransportRequestContext) async throws -> TransportSource) {
        self.source = source
    }

    public func source(for context: TransportRequestContext) async throws -> TransportSource {
        try await source(context)
    }
}

public struct StaticTransportSourceProvider: TransportSourceProvider {
    public var source: TransportSource

    public init(_ source: TransportSource) {
        self.source = source
    }

    public func source(for context: TransportRequestContext) async throws -> TransportSource {
        source
    }
}

/// Named transport slots for ``TransportSource`` values.
///
/// Lookup is fail-closed: a missing slot returns `nil`. There is no silent
/// fallback transport when the selected source is unset.
public struct TransportSourceRegistry: Sendable {
    public var live: (any ClientTransport)?
    public var fixtures: (any ClientTransport)?
    public var replay: (any ClientTransport)?
    public var dynamic: (any ClientTransport)?
    public var stateful: (any ClientTransport)?

    public init(
        live: (any ClientTransport)? = nil,
        fixtures: (any ClientTransport)? = nil,
        replay: (any ClientTransport)? = nil,
        dynamic: (any ClientTransport)? = nil,
        stateful: (any ClientTransport)? = nil
    ) {
        self.live = live
        self.fixtures = fixtures
        self.replay = replay
        self.dynamic = dynamic
        self.stateful = stateful
    }

    public mutating func setTransport(_ transport: any ClientTransport, for source: TransportSource) {
        switch source {
        case .live:
            live = transport
        case .fixtures:
            fixtures = transport
        case .replay:
            replay = transport
        case .dynamic:
            dynamic = transport
        case .stateful:
            stateful = transport
        }
    }

    public func transport(for source: TransportSource) -> (any ClientTransport)? {
        switch source {
        case .live:
            live
        case .fixtures:
            fixtures
        case .replay:
            replay
        case .dynamic:
            dynamic
        case .stateful:
            stateful
        }
    }
}

public struct SourceSwitchingTransportSelector<SourceProvider: TransportSourceProvider>: TransportSelector {
    public var sourceProvider: SourceProvider
    public var registry: TransportSourceRegistry

    public init(
        sourceProvider: SourceProvider,
        registry: TransportSourceRegistry
    ) {
        self.sourceProvider = sourceProvider
        self.registry = registry
    }

    public func transport(for context: TransportRequestContext) async throws -> any ClientTransport {
        let source = try await sourceProvider.source(for: context)
        guard let transport = registry.transport(for: source) else {
            throw TransportSelectionError.missingTransport(source)
        }
        return transport
    }
}

public enum TransportSelectionError: Error, Equatable, Sendable {
    case missingTransport(TransportSource)
}
