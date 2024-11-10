import Dependencies
import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOWebSocket

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
@main
struct EmojiServer {
  @Dependency(\.continuousClock) var clock
  
  let streamTask = LockIsolated<Task<Void, Error>?>(nil)
  let host: String
  let port: Int
  let eventLoopGroop: MultiThreadedEventLoopGroup

  init(host: String, port: Int, eventLoopGroop: MultiThreadedEventLoopGroup) {
    self.host = host
    self.port = port
    self.eventLoopGroop = eventLoopGroop
  }
  
  static func main() async throws {
    let server = EmojiServer(
      host: "localhost",
      port: 8888,
      eventLoopGroop: .singleton
    )
    
    try await server.run()
  }
  
  // TODO: Use for client authentication logic.
//  static let validTokens = [
//    "45B8B350-93FE-42DD-B2F0-9C8B3DA18CE8",
//    "5D8C04DC-1A79-4A45-B6B2-1FA5C203A42D",
//    "618B9882-A7EC-4C46-B58A-C69F5BD4CF14",
//  ]
}
