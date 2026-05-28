# Replay And Recording

Replay serves previously recorded responses. Recording captures live responses
for later replay.

## Replay Keys

``ReplayKey`` contains:

- `operationID`
- optional `requestFingerprint`
- optional `scenario`

The simplest strategy uses only `operationID`.

```swift
let provider = ReplayResponseProvider(
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

``StableRequestFingerprinter`` is stable and non-cryptographic. It is designed
for replay identity, not security.

If `includesBody` is `true`, fingerprinting consumes `HTTPBody`.
``RecordingClientMiddleware`` buffers the request first and can safely forward a
fresh body to the live transport. Custom key strategies should buffer before
using body-based fingerprints.

## File Replay Store

```swift
let store = FileReplayStore(rootDirectory: replayDirectory)
```

Records are JSON files. File names are derived from ``ReplayKey`` through a
``ReplayFileNameStrategy``.

The default ``SafeReplayFileNameStrategy`` percent-encodes key components and
labels component boundaries to avoid lossy filename collisions.

## Replay Provider

```swift
let provider = ReplayResponseProvider(
    store: store,
    keyStrategy: strategy
)

let client = Client(
    serverURL: URL(string: "https://example.com/api")!,
    transport: ProviderTransport(provider: provider)
)
```

Missing records throw ``ReplayError/missingRecord(_:)``. They do not synthesize
HTTP responses.

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

Recording is middleware because it observes the live transport response.

## Body Buffering

`HTTPBody` may be single-pass. ``RecordingClientMiddleware`` buffers request
and response bodies with configurable limits, then creates fresh `HTTPBody`
instances for downstream use.

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

Use `.throw` when recording is required. Use `.ignore` when recording is best
effort.

```swift
let recorder = RecordingClientMiddleware(
    writer: store,
    failureStrategy: .ignore
)
```
