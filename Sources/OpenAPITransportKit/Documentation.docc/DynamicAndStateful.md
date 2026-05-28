# Dynamic And Stateful

Dynamic and stateful providers generate responses programmatically.

## Dynamic Responses

Use ``ClosureResponseProvider`` for stateless response generation.

```swift
let provider = ClosureResponseProvider { context in
    switch context.operationID {
    case "getDashboard":
        return TransportResponse(
            status: .ok,
            body: HTTPBody(#"{"items":[]}"#)
        )
    default:
        return TransportResponse(status: .notFound)
    }
}

let transport = DynamicTransport(provider: provider)
```

Dynamic providers are useful for demos, previews, local development, and tests
that need lightweight branching.

## Stateful Responses

Use ``StatefulResponseProvider`` for a lightweight in-memory backend.

```swift
struct AppState: Sendable {
    var count: Int
}

let provider = StatefulResponseProvider(
    initialState: AppState(count: 0),
    handler: ClosureStatefulResponseHandler<AppState> { context, state in
        var next = state
        next.count += 1

        return StatefulProviderOutput(
            state: next,
            response: TransportResponse(
                status: .ok,
                body: HTTPBody(#"{"ok":true}"#)
            )
        )
    }
)
```

The provider is actor-backed. Requests are serialized before state is read and
updated, so concurrent requests do not observe the same stale state snapshot.

## Keep Domain Logic Outside The Package

State shape belongs to the app. OpenAPITransportKit does not know generated
models, business entities, databases, or app architecture.

## When To Use Dynamic vs Stateful

Use dynamic providers when the response can be computed from the request alone.

Use stateful providers when earlier operations should affect later operations.
