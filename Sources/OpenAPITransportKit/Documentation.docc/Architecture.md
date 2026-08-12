# Architecture

OpenAPITransportKit keeps the transport as the only integration point.

## Component Diagram

```text
Generated Client
  -> ClientMiddleware[]
  -> any ClientTransport
       -> MultiplexingTransport
            -> live: any ClientTransport
            -> fixtures: FixtureTransport
            -> replay: ReplayTransport
            -> dynamic: DynamicTransport
            -> stateful: StatefulTransport

ProviderTransport
  -> ResponseProvider
       -> FixtureResolver + FixtureLoader
       -> ReplayStore + ReplayKeyStrategy
       -> Closure handler
       -> Stateful handler
```

## Transport Layer

``OpenAPITransportKitCore/ProviderTransport`` adapts a
``OpenAPITransportKitCore/ResponseProvider`` to `OpenAPIRuntime.ClientTransport`.

It receives:

- `HTTPRequest`
- `HTTPBody?`
- `baseURL`
- `operationID`

It returns:

- `HTTPResponse`
- `HTTPBody?`

That is intentionally the same low-level surface used by generated clients.

## Provider Layer

``OpenAPITransportKitCore/ResponseProvider`` is the stable extension point for response sources.

Providers should not know generated DTOs or domain models. They operate on
``OpenAPITransportKitCore/TransportRequestContext`` and return
``OpenAPITransportKitCore/TransportResponse``.

## Source Selection Layer

``OpenAPITransportKitCore/MultiplexingTransport`` delegates to another transport
selected per request. This supports app-level mode switching without putting app
concerns into the library.

Built-in sources use ``OpenAPITransportKitCore/TransportSource`` values such as
`.live`, `.fixtures`, `.replay`, `.dynamic`, and `.stateful`.
``OpenAPITransportKitCore/TransportSourceRegistry`` exposes named slots for those
sources instead of a string-keyed public dictionary. Lookup is fail-closed: a
missing slot surfaces ``OpenAPITransportKitCore/TransportSelectionError/missingTransport(_:)``
instead of silently substituting another transport. Custom selection belongs in
a user-provided ``OpenAPITransportKitCore/TransportSelector``.

## Middleware Layer

Recording is a middleware concern because it needs to observe live responses.
``OpenAPITransportKitReplay/RecordingClientMiddleware`` captures the
request/response exchange and writes a ``OpenAPITransportKitReplay/ReplayRecord``
while still returning a usable body to the generated client.

## Why Not Mock APIProtocol?

Generated `APIProtocol` mocks are type-safe, but they bypass request
serialization, response deserialization, and generated status handling. This
package exists specifically to keep that pipeline active.

## Why Not A Mock Server?

A mock server adds ports, startup ordering, process lifecycle, and network
behavior. OpenAPITransportKit stays in-process and multiplatform.

## Why Not URLProtocol?

`URLProtocol` is Apple-platform-specific and URL-based. This package targets
Swift Multiplatform and uses `operationID` as the stable lookup key.
