import Dependencies
import EmojiServiceProtocolModels
import NIOCore
import NIOWebSocket

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension EmojiServer {
  
  func handleRequest(_ request: Request) async throws {
    @Dependency(EmojiGenerator.self) var emojis
    
    switch request {
    case let .getRandomEmojiList(payload):
      let count = payload.count ?? 1
      let emojiList = emojis.list(count: count)
      let payload = Response.getRandomEmojiList(.init(emojis: emojiList))
      let response = Response.Result.succcess(payload)
      
      try await self.sendMessage(.response(response))
      
    case .startStream:
      // Streams a random emoji every second.
      self.startStream.withValue {
        $0 = Task {
          let message = Message.response(.succcess(.startStream))
          try await self.sendMessage(message)
          
          for await _ in self.clock.timer(interval: .seconds(1)) {
            let message = Message.event(
              .emojiDidChangedEvent(.init(newEmoji: emojis.singleOne()))
            )
            try await self.sendMessage(message)
          }
        }
      }
      
    case .stopStream:
      // Stops the stream of emojis.
      self.startStream.value?.cancel()
      let message = Message.response(.succcess(.stopStream))
      try await self.sendMessage(message)
    }
  }
}

