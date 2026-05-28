public import OpenAPITransportKitCore

public struct FixtureScenario: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static let success: Self = "success"
    public static let empty: Self = "empty"
    public static let error: Self = "error"
}

public protocol ScenarioProvider: Sendable {
    func scenario(for context: TransportRequestContext) async -> FixtureScenario
}

public struct StaticScenarioProvider: ScenarioProvider {
    public var scenario: FixtureScenario

    public init(_ scenario: FixtureScenario) {
        self.scenario = scenario
    }

    public func scenario(for context: TransportRequestContext) async -> FixtureScenario {
        scenario
    }
}

public struct ClosureScenarioProvider: ScenarioProvider {
    private let resolve: @Sendable (TransportRequestContext) async -> FixtureScenario

    public init(_ resolve: @escaping @Sendable (TransportRequestContext) async -> FixtureScenario) {
        self.resolve = resolve
    }

    public func scenario(for context: TransportRequestContext) async -> FixtureScenario {
        await resolve(context)
    }
}

