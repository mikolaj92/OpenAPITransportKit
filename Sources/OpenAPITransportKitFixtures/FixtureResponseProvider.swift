public import OpenAPITransportKitCore
import HTTPTypes
import OpenAPIRuntime

public struct FixtureResponseProvider: ResponseProvider {
    public var resolver: any FixtureResolver
    public var loader: any FixtureLoader
    public var scenarioProvider: any ScenarioProvider
    public var defaults: FixtureResponseDefaults

    public init(
        loader: any FixtureLoader,
        scenarioProvider: any ScenarioProvider = StaticScenarioProvider(.success),
        resolver: any FixtureResolver = DotSeparatedFixtureResolver(),
        defaults: FixtureResponseDefaults = .jsonOK
    ) {
        self.resolver = resolver
        self.loader = loader
        self.scenarioProvider = scenarioProvider
        self.defaults = defaults
    }

    public func response(for context: TransportRequestContext) async throws -> TransportResponse {
        let scenario = await scenarioProvider.scenario(for: context)
        let reference = try await resolver.reference(for: context, scenario: scenario)
        let payload = try await loader.load(reference)
        let status = payload.metadata?.status ?? defaults.status
        let headerFields = Self.mergedHeaderFields(
            defaults: defaults.headerFields,
            overrides: payload.metadata?.headerFields
        )

        return TransportResponse(
            status: status,
            headerFields: headerFields,
            body: HTTPBody(payload.data)
        )
    }

    private static func mergedHeaderFields(defaults: HTTPFields, overrides: HTTPFields?) -> HTTPFields {
        guard let overrides else {
            return defaults
        }

        var fields = defaults
        var overriddenNames = Set<HTTPField.Name>()
        for field in overrides where !overriddenNames.contains(field.name) {
            fields[field.name] = nil
            overriddenNames.insert(field.name)
        }
        for field in overrides {
            fields.append(field)
        }
        return fields
    }
}
