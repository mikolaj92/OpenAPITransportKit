public import OpenAPITransportKitCore

public protocol FixtureResolver: Sendable {
    func reference(
        for context: TransportRequestContext,
        scenario: FixtureScenario
    ) async throws -> FixtureReference
}

public struct DotSeparatedFixtureResolver: FixtureResolver {
    public var fileExtension: String

    public init(fileExtension: String = "json") {
        self.fileExtension = fileExtension
    }

    public func reference(
        for context: TransportRequestContext,
        scenario: FixtureScenario
    ) async throws -> FixtureReference {
        .init(rawValue: "\(context.operationID).\(scenario.rawValue).\(fileExtension)")
    }
}

public struct ClosureFixtureResolver: FixtureResolver {
    private let resolve: @Sendable (TransportRequestContext, FixtureScenario) async throws -> FixtureReference

    public init(
        _ resolve: @escaping @Sendable (TransportRequestContext, FixtureScenario) async throws -> FixtureReference
    ) {
        self.resolve = resolve
    }

    public func reference(
        for context: TransportRequestContext,
        scenario: FixtureScenario
    ) async throws -> FixtureReference {
        try await resolve(context, scenario)
    }
}

