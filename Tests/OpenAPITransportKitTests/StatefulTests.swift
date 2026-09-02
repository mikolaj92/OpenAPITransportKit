import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPITransportKitCore
import OpenAPITransportKitDynamic
import OpenAPITransportKitFixtures
import OpenAPITransportKitReplay
import OpenAPITransportKitStateful
import Testing

@Suite
struct StatefulTests {

  @Test
  func testStatefulResponseProviderPersistsUserDefinedState() async throws {
    struct CounterState: Sendable, Equatable {
      var count: Int
    }

    let transport = StatefulTransport<CounterState>(initialState: CounterState(count: 0)) {
      _, state in
      let nextState = CounterState(count: state.count + 1)
      return StatefulProviderOutput(
        state: nextState,
        response: TransportResponse(status: .ok, body: HTTPBody("\(nextState.count)"))
      )
    }
    let provider = transport.provider

    let (_, firstBody) = try await transport.send(
      dashboardRequest(),
      body: nil,
      baseURL: baseURL(),
      operationID: "getDashboard"
    )
    let (_, secondBody) = try await transport.send(
      dashboardRequest(),
      body: nil,
      baseURL: baseURL(),
      operationID: "getDashboard"
    )

    let firstText = try await String(collecting: #require(firstBody), upTo: 1024)
    let secondText = try await String(collecting: #require(secondBody), upTo: 1024)

    #expect(firstText == "1")
    #expect(secondText == "2")
    let currentState = await provider.currentState()
    #expect(currentState == CounterState(count: 2))
  }

  @Test
  func testStatefulProviderTransportPersistsUserDefinedStateWithCustomHandler() async throws {
    struct CounterState: Sendable, Equatable {
      var count: Int
    }

    let provider = StatefulResponseProvider(
      initialState: CounterState(count: 0),
      handler: ClosureStatefulResponseHandler<CounterState> { _, state in
        let nextState = CounterState(count: state.count + 1)
        return StatefulProviderOutput(
          state: nextState,
          response: TransportResponse(status: .ok, body: HTTPBody("\(nextState.count)"))
        )
      }
    )
    let transport = StatefulProviderTransport(provider: provider)

    let (_, firstBody) = try await transport.send(
      dashboardRequest(),
      body: nil,
      baseURL: baseURL(),
      operationID: "getDashboard"
    )
    let (_, secondBody) = try await transport.send(
      dashboardRequest(),
      body: nil,
      baseURL: baseURL(),
      operationID: "getDashboard"
    )

    let firstText = try await String(collecting: #require(firstBody), upTo: 1024)
    let secondText = try await String(collecting: #require(secondBody), upTo: 1024)

    #expect(firstText == "1")
    #expect(secondText == "2")
    let currentState = await provider.currentState()
    #expect(currentState == CounterState(count: 2))
  }

  @Test
  func testStatefulResponseProviderSerializesConcurrentMutations() async throws {
    struct CounterState: Sendable, Equatable {
      var count: Int
    }

    let provider = StatefulResponseProvider(
      initialState: CounterState(count: 0),
      handler: ClosureStatefulResponseHandler<CounterState> { _, state in
        await Task.yield()
        let nextState = CounterState(count: state.count + 1)
        return StatefulProviderOutput(
          state: nextState,
          response: TransportResponse(status: .ok, body: HTTPBody("\(nextState.count)"))
        )
      }
    )

    let values = try await withThrowingTaskGroup(of: Int.self) { group in
      for _ in 0..<20 {
        group.addTask {
          let output = try await provider.response(
            for: TransportRequestContext(
              request: dashboardRequest(),
              body: nil,
              baseURL: baseURL(),
              operationID: "getDashboard"
            )
          )
          let body = try #require(output.body)
          let text = try await String(collecting: body, upTo: 1024)
          return try #require(Int(text))
        }
      }

      var values = [Int]()
      for try await value in group {
        values.append(value)
      }
      return values
    }
    let currentState = await provider.currentState()

    #expect(currentState == CounterState(count: 20))
    #expect(values.sorted() == Array(1...20))
  }

  @Test
  func testStatefulResponseProviderDoesNotCommitCancelledMutation() async throws {
    struct CounterState: Sendable, Equatable {
      var count: Int
    }

    let provider = StatefulResponseProvider(
      initialState: CounterState(count: 0),
      handler: ClosureStatefulResponseHandler<CounterState> { _, state in
        try await Task.sleep(nanoseconds: 100_000_000)
        let nextState = CounterState(count: state.count + 1)
        return StatefulProviderOutput(
          state: nextState,
          response: TransportResponse(status: .ok)
        )
      }
    )
    let task = Task {
      try await provider.response(
        for: TransportRequestContext(
          request: dashboardRequest(),
          body: nil,
          baseURL: baseURL(),
          operationID: "getDashboard"
        )
      )
    }

    await Task.yield()
    task.cancel()

    do {
      _ = try await task.value
      Issue.record("Expected cancellation.")
    } catch is CancellationError {
    }
    let currentState = await provider.currentState()

    #expect(currentState == CounterState(count: 0))
  }

}
