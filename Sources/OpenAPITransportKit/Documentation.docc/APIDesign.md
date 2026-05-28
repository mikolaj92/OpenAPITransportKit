# API Design

The API is intentionally small and transport-centered.

## Stable Core

The stable center is:

- ``OpenAPITransportKitCore/ProviderTransport``
- ``OpenAPITransportKitCore/ResponseProvider``
- ``OpenAPITransportKitCore/TransportRequestContext``
- ``OpenAPITransportKitCore/TransportResponse``

Everything else adapts a response source to this shape.

The user-facing API should prefer concrete transport facades:

- ``OpenAPITransportKitFixtures/FixtureTransport``
- ``OpenAPITransportKitReplay/ReplayTransport``
- ``OpenAPITransportKitDynamic/DynamicTransport``
- ``OpenAPITransportKitStateful/StatefulTransport``

``OpenAPITransportKitCore/ProviderTransport`` remains the low-level adapter for custom
``OpenAPITransportKitCore/ResponseProvider`` implementations.

## Extension Points

Users can provide:

- custom `ClientTransport` implementations;
- custom ``OpenAPITransportKitCore/ResponseProvider`` implementations;
- custom ``OpenAPITransportKitFixtures/FixtureResolver`` implementations;
- custom ``OpenAPITransportKitFixtures/ScenarioProvider`` implementations;
- custom ``OpenAPITransportKitFixtures/FixtureLoader`` implementations;
- custom ``OpenAPITransportKitReplay/ReplayStore`` implementations;
- custom ``OpenAPITransportKitReplay/ReplayKeyStrategy`` implementations;
- custom ``OpenAPITransportKitReplay/RequestFingerprinter`` implementations;
- custom ``OpenAPITransportKitStateful/StatefulResponseHandler`` implementations;
- custom ``OpenAPITransportKitCore/TransportSourceProvider`` implementations.

## Error Philosophy

Missing local assets are configuration errors.

Examples:

- missing fixture;
- missing replay record;
- invalid metadata;
- invalid replay file.

These errors should throw Swift errors. They should not become synthetic HTTP
responses unless the user explicitly writes a provider that does that.

## SemVer Before 1.0

Before `1.0.0`, source-breaking changes are allowed if they simplify the
long-term API.

Before `1.0.0`, review these names carefully:

- `ProviderTransport`
- `ResponseProvider`
- `FixtureLoader`
- `ReplayStore`
- `RecordingClientMiddleware`
- `StatefulResponseProvider`

## SemVer After 1.0

After `1.0.0`:

- additive protocols and providers are minor releases;
- bug fixes are patch releases;
- source-breaking API changes are major releases.
