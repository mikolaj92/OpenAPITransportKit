# Architecture

OpenAPITransportKit keeps the transport as the only integration point.

## Component Diagram

```text
Generated Client
  -> ClientMiddleware[]
  -> any ClientTransport
       -> MultiplexingTransport
            -> live: any ClientTransport
            -> fixtures: ProviderTransport(FixtureResponseProvider)
            -> replay: ProviderTransport(ReplayResponseProvider)
            -> dynamic: ProviderTransport(ClosureResponseProvider)
            -> stateful: ProviderTransport(StatefulResponseProvider)
            -> custom: any ClientTransport

ProviderTransport
  -> ResponseProvider
       -> FixtureResolver + FixtureLoader
       -> ReplayStore + ReplayKeyStrategy
       -> Closure handler
       -> Stateful handler
```

## Transport Layer

``ProviderTransport`` adapts a ``ResponseProvider`` to
`OpenAPIRuntime.ClientTransport`.

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

``ResponseProvider`` is the stable extension point for response sources.

Providers should not know generated DTOs or domain models. They operate on
``TransportRequestContext`` and return ``TransportResponse``.

## Routing Layer

``MultiplexingTransport`` delegates to another transport selected per request.
This supports app-level mode switching without putting app concerns into the
library.

## Middleware Layer

Recording is a middleware concern because it needs to observe live responses.
``RecordingClientMiddleware`` captures the request/response exchange and writes
a ``ReplayRecord`` while still returning a usable body to the generated client.

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

