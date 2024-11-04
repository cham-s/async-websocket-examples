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
      // Starts listening for emoji messages
      for await message in try await webSocket.receive(id)
        .emojiMessage() {
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
  func emojiMessage() throws -> AsyncStream<Message> {
    self
      .log(action: frameLogger)
      .on(\.message.text)
      .map {
        let data = $0.data(using: .utf8)!
        return try JSONDecoder().decode(Message.self, from: data)
      }
      .eraseToStream()
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
