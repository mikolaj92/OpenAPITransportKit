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

public struct TransportIdentifier: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

public protocol TransportIdentifierProvider: Sendable {
    func identifier(for context: TransportRequestContext) async throws -> TransportIdentifier
}

public struct ClosureTransportIdentifierProvider: TransportIdentifierProvider {
    private let identify: @Sendable (TransportRequestContext) async throws -> TransportIdentifier

    public init(_ identify: @escaping @Sendable (TransportRequestContext) async throws -> TransportIdentifier) {
        self.identify = identify
    }

    public func identifier(for context: TransportRequestContext) async throws -> TransportIdentifier {
        try await identify(context)
    }
}

public struct RoutingTransportSelector<IdentifierProvider: TransportIdentifierProvider>: TransportSelector {
    public var identifierProvider: IdentifierProvider
    public var routes: [TransportIdentifier: any ClientTransport]
    public var defaultTransport: (any ClientTransport)?

    public init(
        identifierProvider: IdentifierProvider,
        routes: [TransportIdentifier: any ClientTransport],
        defaultTransport: (any ClientTransport)? = nil
    ) {
        self.identifierProvider = identifierProvider
        self.routes = routes
        self.defaultTransport = defaultTransport
    }

    public func transport(for context: TransportRequestContext) async throws -> any ClientTransport {
        let identifier = try await identifierProvider.identifier(for: context)
        if let transport = routes[identifier] {
            return transport
        }
        if let defaultTransport {
            return defaultTransport
        }
        throw TransportRoutingError.missingRoute(identifier)
    }
}

public enum TransportRoutingError: Error, Equatable, Sendable {
    case missingRoute(TransportIdentifier)
}

