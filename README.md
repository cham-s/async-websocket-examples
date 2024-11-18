# AsyncWebSocket Examples

## Overview

Examples that demonstrates some uses of the  [async-websocket](https://github.com/cham-s/async-websocket) clilent.

## Contents

- [Demo Servers](#servers)

- [Demo Applications](#applications)

### Demo Servers<a name="servers"></a>

The package contains demo servers that can be run locally to test the library.

They all respond to the `ping` frame with a `pong` frame.

After runing the server it can be accessed via the URL `ws://localhost` and port `8888`

- *EchoServer*: simply echoes each frame sent by the client.

- *TimeServer*: sends the date and time of the server every second as a text frame.

- *EmojiServer*: A "more advanced" WebSocket server that accepts specific requests based on an rpc.

### How to run the server

Inside the package directory run one of the following command

```shell
swift run EchoServer
swift run TimerServer
swift run EmojisServer
```

### Demo Applications<a name="applications"></a>

Demonstrates some uses of the library.

- [Getting Started](#started)

- [Ping Interval](#interval)

- [On Operator](#listen)

- [Log Operator](#log)

- [😀 Emojis](#emojis)

#### Gettings Started<a name="started"></a>

Sends frames to the server and prints each response to the console.

```shell
swift run GettingsStartedDemo
```

```swift
import AsyncWebSocket
import Foundation
@main
@MainActor
struct MainApp {
  static func main() async throws {

    /// Default instance of a WebSocket client.
    let webSocket = AsyncWebSocketClient.default

    /// A uniquely identifiable value to use for subsequent requests to the server.
    let id = AsyncWebSocketClient.ID()

    /// Connectivity status subscription
    let connectionStatus  = try await webSocket.open(
      AsyncWebSocketClient.Settings(
        id: id,
        url: "ws://localhost",
        port: 8888
      )
    )

    // Starts listening for connection events.
    for await status in connectionStatus {
      switch status {
      case .connected:
        print("[WebSocket - Status - Connected]: Connected to the server!")
        // At this point a connection with the server has been established.
        // We can start listening for incoming frames or send frames to the server.
        async let listening: Void = startListeningForIncomingFrames()
        async let sending: Void = sendFramesToTheServer()

        try await listening
        try await sending

      case .connecting:
        print("[WebSocket - Status - Connecting]: Connecting...")
      case let .didClose(code):
        print("[WebSocket - Status - Close]: Connection with server did close with the code: \(code)")
      case let .didFail(error):
        print("[WebSocket - Status - Failure]: Connection with server did fail with error: \(error)")
      }
    }

    /// Initiates the act of receiving frames from the server.
    @Sendable
    func startListeningForIncomingFrames() async throws {
      let frames = try await webSocket.receive(id)

      for await frame in frames {
        switch frame {
        case let .message(.binary(data)):
          print("[WebSocket - Frame - Message.binary]: \(data)")
        case let .message(.text(string)):
          print("[WebSocket - Frame - Message.text]: \(string)")
        case let .ping(data):
          print("[WebSocket - Frame - Ping]: \(data)")
        case let .pong(data):
          print("[WebSocket - Frame - Pong]: \(data)")
        case let .close(code):
          print("[WebSocket - Frame - Close]: \(code)")
        }
      }
    }

    /// Sends a series of frames to the server.
    @Sendable
    func sendFramesToTheServer() async throws {
      let data = "Hello".data(using: .utf8)!
      try await webSocket.send(id, .message(.binary(data)))
      try await webSocket.send(id, .message(.text("Hello")))
      try await webSocket.send(id, .ping())
//      try await webSocket.send(id, .close(code: .goingAway))

    }
  }
}
```

#### Ping Interval<a name="interval"></a>

Some servers require the client to ping them at a specified interval to keep the connection alive. This demo shows how to set up this operation.

```shell
swift run PingIntervalDemo
```

```swift
import AsyncWebSocketClient
import AsyncWebSocketClientLive
import AsyncWebSocketOperators
import Foundation

// This demo checks the ping interval option in the Settings.
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
@main
@MainActor
struct MainApp {
  static func main() async throws {
    let webSocket = AsyncWebSocketClient.default

    /// A uniquely identifiable value  used for subsequent requests to the server.
    let id = AsyncWebSocketClient.ID()

    /// Connectivity status subscription.
    /// Indicates the interval for the sending a ping frame to the server.
    let connection = try await webSocket.open(
      AsyncWebSocketClient.Settings(
        id: id,
        url: "ws://localhost",
        port: 8888,
        pingInterval: TimeInterval(1) // every second
      )
    )

    for await _ in connection.on(\.connected) {
      let responses = try await webSocket
        .receive(id)
        .on(\.pong)

      for await _ in responses {
        print("Connection with server is still alive")
      }
    }
  }
}
```

#### On Operator<a name="listen"></a>

Demonstrates the use of the `on` operator to focus on a particular event.

```shell
swift run OnOperatorDemo
```

```swift
import AsyncWebSocketClient
import AsyncWebSocketClientLive
import AsyncWebSocketOperators

@main
@MainActor
struct MainApp {
  static func main() async throws {

    /// Default instance of a WebSocket client.
    let webSocket = AsyncWebSocketClient.default

    /// A uniquely identifiable value to use for subsequent requests to the server.
    let id = AsyncWebSocketClient.ID()

    /// Connectivity status subscription
    let connection = try await webSocket.open(
      AsyncWebSocketClient.Settings(
        id: id,
        url: "ws://localhost",
        port: 8888
      )
    )

    // The follwing code combines the use of log() and on().
    // Cases not handled by the on() operator have a default behiavor of logging event
    // by levaraging the log() operator.
    for await _ in connection
      .log()
      .on(\.connected) {
      Task {
        let notifications = try await webSocket.receive(id)
        for await messageText in notifications.on(\.message.text) {
          print("Message received: ", messageText)
        }
      }
    }
  }
}
```

#### Log Operator<a name="log"></a>

Demonstrates the use of the `log ` operator for each event received.

```shell
swift run LogOperatorDemo
```

```swift
import AsyncWebSocketClient
import AsyncWebSocketClientLive
import AsyncWebSocketOperators
import Foundation

@main
@MainActor
struct MainApp {
  static func main() async throws {

    /// Default instance of a WebSocket client.
    let webSocket = AsyncWebSocketClient.default

    /// A uniquely identifiable value to use for subsequent requests to the server.
    let id = AsyncWebSocketClient.ID()

    /// Connectivity status subscription
    let connection = try await webSocket.open(
      AsyncWebSocketClient.Settings(
        id: id,
        url: "ws://localhost",
        port: 8888
      )
    )

    // The default behaviour of the .log() operator without argument simply prints
    // a formatted log of all occuring event to the console.
    // The caller can optionally provide a Logger with a custom behaviour.
    for await status in connection.log() {
      if status.is(\.connected) {
        for await string in try await webSocket.receive(id)
          .log()
          .on(\.message.text) {
          print(string)
        }
      }
    }
  }
}
```

#### 😀 Emojis<a name="emojis"></a>

Demonstrates the use of operators for only listening for text frames and parsing the result to Swift types after performing a specific request to the server using an rpc `The Emoji Service Protocol`. 

```shell
swift run EmojisDemo
```

```swift
import AsyncWebSocketClient
import AsyncWebSocketClientLive
import AsyncWebSocketOperators
import Dependencies
import EmojiServiceProtocolModels
import Foundation
import Logging

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
@main
@MainActor
struct MainApp {
  static func main() async throws {
    @Dependency(\.webSocket) var webSocket

    let startStreamTask = LockIsolated<Task<Void, Error>?>(nil)

    /// A uniquely identifiable value  used for subsequent requests to the server.
    let id = AsyncWebSocketClient.ID()

    /// Connectivity status subscription
    let connection = try await webSocket.open(
      AsyncWebSocketClient.Settings(
        id: id,
        url: "ws://localhost",
        port: 8888
      )
    )

    for await _ in connection
  .log()
  .on(\.connected)
{
  let messages = try await webSocket.receive(id).emojiMessage()
  // Starts listening for emoji messages
  for await message in messages {
    switch message {
    case let .welcome(welcome):
      print(welcome.message)
      startStreamTask.withValue {
        $0 = Task {
          try await request(id: id, request: .startStream)
        }
      }
    case let .event(event):
      switch event {
      case let .emojiDidChangedEvent(emoji):
        print("New emoji: ", emoji.newEmoji)
      }
    case let .response(result):
      try await onResponse(result)
    case .request:
      // Not handled by the client
      break
    }
  }
}

    // Awaiting for possible error thrown during tasks execution
    try await startStreamTask.value?.value
    startStreamTask.withValue { $0 = nil }

    @Sendable
    func onResponse(_ result: Response.Result) async throws {
      switch result {
      case let .succcess(response):
        if response.is(\.startStream) {
          print("Starting stream")
        } else if response.is(\.stopStream) {
          // When the stream stops we print a message to the console
          print("Stopping stream")
        }
      case let .failure(requestError):
        print(
          "Request failed with code: \(requestError.reason)",
          "message:", requestError.message ?? "No message provided"
        )
      }
    }

    @Sendable
    func request(
      id: AsyncWebSocketClient.ID,
      request: Request
    ) async throws {
      @Dependency(\.webSocket) var webSocket
      let message = Message.request(request)
      let data = try JSONEncoder().encode(message)
      let text = String(data: data, encoding: .utf8)!
      try await webSocket.send(id, .message(.text(text)))
    }
  }
}

extension AsyncStream where Element == AsyncWebSocketClient.Frame {
  /// Transforms a stream of Frame into a stream of Emoji Message
  func emojiMessage() -> AsyncStream<Message> {
    self
      .log(action: frameLogger)
      .success(of: Message.self)
  }
}

fileprivate let frameLogger: @Sendable (AsyncWebSocketClient.Frame) -> Void =
{ (frame: AsyncWebSocketClient.Frame) in
  var logger = Logger(label: "Emoji-Server-Client")
  guard let text = frame[case: \.message.text]
  else {
    logger.info("", metadata:["Frame Update":  " \(frame)"])
    return
  }

  logger.info("\n\n\(formatted(title: "Received Text Frame", message: text))\n")
}

fileprivate func formatted(
  title: String,
  message: String
) -> String {
  let messageSplit = message.split(separator: "\n")
  let maxCount = messageSplit.map(\.count).max() ?? 0
  let received = " \(title) "
  let count = maxCount / 2

  // String of repeating character
  let `repeat`: (Character, Int) -> String = String.init(repeating:count:)
  let headerContent = "\(`repeat`("⎺", count))\(received)\(`repeat`("⎺", count))"
  let header = "⌈\(headerContent)⌉"
  let footer = "⌊\(`repeat`("⎽", (count * 2) + received.count))⌋"

  let body = messageSplit.reduce(into: [String]()) { result, line in
    let leadingSpaces = `repeat`(" ", 2)
    let lineContent = "\(leadingSpaces)\(line)"
    result.append(lineContent)
  }.joined(separator: "\n")

  return """
  \(header)

  \(body)

  \(footer)
  """
}
```

<details>
<summary>The Emoji Service Protocol</summary>

```swift
import CasePaths
import Foundation

public enum Message: Sendable, Equatable, Codable {
  case welcome(Welcome)
  case event(Event)
  case request(Request)
  case response(Response.Result)
}

public struct Welcome: Sendable, Codable, Equatable {
  public let message: String

  public init(message: String) {
    self.message = message
  }
}

public struct RequestError: Sendable, Codable, Equatable, Error {
  public let reason: Reason
  public let message: String?

  public init(reason: Reason, message: String?) {
    self.reason = reason
    self.message = message
  }

  public enum Reason: Sendable, Codable, Equatable {
    /// The data provided is not a valid JSON format
    case malformedJSONResquest
  }
}

// MARK: - Events Payloads

/// The current main emoji changed.
public struct EmojiDidChangedEvent: Sendable, Codable, Equatable {
  /// Value of the current emoji.
  public let newEmoji: String

  public init(newEmoji: String) {
    self.newEmoji = newEmoji
  }
}

// MARK: - Requests Payloads
/// Gets a random list of emojis based on the requested count.
///
/// Defaults to one if no count is specified.
public struct GetRandomEmojisRequest: Sendable, Codable, Equatable {
  public let count: Int?

  public init(count: Int? = nil) {
    self.count = count
  }
}

// MARK: - Responses Payloads
/// Gets a random list of emojis based on the requested count.
///
/// Defaults to one if a count is not specified.
public struct GetRandomEmojisResponse: Sendable, Codable, Equatable {
  /// A list of emojis.
  public let emojis: [String]

  public init(emojis: [String]) {
    self.emojis = emojis
  }
}

// MARK: - Event
@CasePathable
/// An event coming from the server.
public enum Event: Sendable, Codable, Equatable {
  /// The current main emoji did changed.
  case emojiDidChangedEvent(EmojiDidChangedEvent)
}

// MARK: - Request
@CasePathable
/// A request to be sent to the server.
public enum Request: Sendable, Codable, Equatable {
  /// Gets a random list of emojis based on the requested count.
  case getRandomEmojiList(GetRandomEmojisRequest)
  /// Starts the stream of emojis.
  case startStream
  /// Stops the stream of emojis.
  case stopStream
}

// MARK: - Response
@CasePathable
/// A response resulting from a previous request.
public enum Response: Sendable, Codable, Equatable {
  /// A list of emojis based on the requested count.
  case getRandomEmojiList(GetRandomEmojisResponse)
  /// Started the stream of emojis.
  case startStream
  /// Stopped the stream of emojis.
  case stopStream

  @CasePathable
  public enum Result: Sendable, Codable, Equatable {
    case succcess(Response)
    case failure(RequestError)
  }
}
```

</details>

## Credits and inspirations

The echo server and the time server are inspired from example servers from the [swift-nio](https://github.com/apple/swift-nio) package.

For the more advanced WebSocket server the `Emoji Service Server`, the idea of using emojis as stream of data comes the WWDC video [Meet Swift OpenAPI Generator - WWDC23 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2023/10171/) that presents how to use the Swift OpenAPI Generator api. 

The package [swift-gen](https://github.com/pointfreeco/swift-gen) is used for generating random emojis.

[swift-case-paths](https://github.com/pointfreeco/swift-case-paths) is used to improve the use of enum when receiving message from the server in the Emoji Service Protocol.
