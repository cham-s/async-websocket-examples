# AsyncWebSocket Examples

## Overview

Examples that demonstrates some uses of the  [async-websocket](https://github.com/cham-s/async-websocket) clilent.

## Contents

#### Demo Servers

The package contains three demo servers that can be run locally to test the library.

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

### Demo Applications

Four demo applications are provided to communicate with the servers

- *GettingsStartedDemo*: sends frames to the server and prints each response to the console

- *ListenOperatorDemo*: demonstrates the use of the `on(Event)` operator to focus on a particular event.

- *LogOperatorDemo*: Demonstrates the use of the `log() ` operator for each event received.

- *EmojisDemo*: demonstrates the use of operators for only listening for text frames and parsing the result to Swift types after performing a specific request to the server using an rpc `The Emoji Service Protocol`. 

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

### How to run the demo

Inside the package directory run one of the following command

```shell
swift run GettingsStartedDemo
swift run ListenOperatorDemo
swift run LogOperatorDemo
swift run EmojisDemo
```

## Credits and inspirations

The echo server and the time server are inspired from example servers from the [swift-nio](https://github.com/apple/swift-nio) package.

For the more advanced WebSocket server the `Emoji Service Server`, the idea of using emojis as stream of data comes the WWDC video [Meet Swift OpenAPI Generator - WWDC23 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2023/10171/) that presents how to use the Swift OpenAPI Generator api. 

The package [swift-gen](https://github.com/pointfreeco/swift-gen) is used for generating random emojis.

[swift-case-paths](https://github.com/pointfreeco/swift-case-paths) is used to improve the use of enum when receiving message from the server in the Emoji Service Protocol.
