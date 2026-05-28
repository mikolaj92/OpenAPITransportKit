# API Design

The API is intentionally small and transport-centered.

## Stable Core

The stable center is:

- ``ProviderTransport``
- ``ResponseProvider``
- ``TransportRequestContext``
- ``TransportResponse``

Everything else adapts a response source to this shape.

The user-facing API should prefer concrete transport facades:

- ``FixtureTransport``
- ``ReplayTransport``
- ``DynamicTransport``
- ``StatefulTransport``

``ProviderTransport`` remains the low-level adapter for custom
``ResponseProvider`` implementations.

## Extension Points

Users can provide:

- custom `ClientTransport` implementations;
- custom ``ResponseProvider`` implementations;
- custom ``FixtureResolver`` implementations;
- custom ``ScenarioProvider`` implementations;
- custom ``FixtureLoader`` implementations;
- custom ``ReplayStore`` implementations;
- custom ``ReplayKeyStrategy`` implementations;
- custom ``RequestFingerprinter`` implementations;
- custom ``StatefulResponseHandler`` implementations.
- custom ``TransportSourceProvider`` implementations.

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
