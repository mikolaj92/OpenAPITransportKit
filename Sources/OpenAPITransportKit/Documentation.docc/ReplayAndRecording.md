# Replay And Recording

Replay serves previously recorded responses. Recording captures live responses
for later replay.

## Replay Keys

``OpenAPITransportKitReplay/ReplayKey`` contains:

- `operationID`
- optional `requestFingerprint`
- optional `scenario`

The simplest strategy uses only `operationID`.

```swift
let transport = ReplayTransport(
    store: store,
    keyStrategy: OperationIDReplayKeyStrategy()
)
```

Use fingerprints when one operation can produce multiple responses based on
query, headers, or body.

```swift
let strategy = FingerprintedReplayKeyStrategy(
    fingerprinter: StableRequestFingerprinter(
        includedHeaderNames: ["Accept", "X-Scenario"],
        includesBody: false
    ),
    scenario: "success"
)
```

``OpenAPITransportKitReplay/StableRequestFingerprinter`` is stable and
non-cryptographic. It is designed for replay identity, not security.

If `includesBody` is `true`, fingerprinting consumes `HTTPBody`.
``OpenAPITransportKitReplay/RecordingClientMiddleware`` buffers the request first
and can safely forward a fresh body to the live transport. Custom key strategies
should buffer before using body-based fingerprints.

## File Replay Store

JSON uses `ReplayRecord.Codable`, including HTTPTypes' `HTTPResponse` encoding.
Writes are atomic; missing files return `nil`, while read or decoding failures
throw `ReplayError.invalidRecord(_:_:)` with the requested key.

File names are derived from
``OpenAPITransportKitReplay/ReplayKey`` through a
``OpenAPITransportKitReplay/ReplayFileNameStrategy``.

The default ``OpenAPITransportKitReplay/SafeReplayFileNameStrategy``
percent-encodes key components and labels component boundaries to avoid lossy
filename collisions.

## Replay Transport

```swift
let transport = ReplayTransport(
    store: store,
    keyStrategy: strategy
)

let client = Client(
    serverURL: URL(string: "https://example.com/api")!,
    transport: transport
)
```

The transport turns a store's `nil` into `ReplayError.missingRecord(_:)`,
not an HTTP response.

## Recording Middleware

```swift
let recorder = RecordingClientMiddleware(
    writer: FileReplayStore(rootDirectory: replayDirectory),
    keyStrategy: strategy
)

let client = Client(
    serverURL: URL(string: "https://example.com/api")!,
    transport: liveTransport,
    middlewares: [recorder]
)
```

## Body Buffering

`HTTPBody` may be single-pass.
``OpenAPITransportKitReplay/RecordingClientMiddleware`` buffers request and
response bodies with configurable limits, then creates fresh `HTTPBody` instances
for downstream use.

Defaults:

- request body limit: 1 MB
- response body limit: 10 MB

Tune these limits for large payloads.

```swift
let recorder = RecordingClientMiddleware(
    writer: store,
    maximumRequestBodyBytes: 256 * 1024,
    maximumResponseBodyBytes: 2 * 1024 * 1024
)
```

## Failure Strategy

If key generation fails, `.ignore` calls `next` with a fresh buffered request
body and skips recording; `.throw` (the default) throws before calling `next`.

Writer errors occur after the live response is received and buffered: `.ignore`
returns that response, while `.throw` propagates the error.

Errors from `next` or request/response buffering propagate under either strategy.
