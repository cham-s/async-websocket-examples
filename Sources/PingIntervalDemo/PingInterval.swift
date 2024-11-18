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
    
    /// Connectivity status subscription
    let connection = try await webSocket.open(
      AsyncWebSocketClient.Settings(
        id: id,
        url: "ws://localhost",
        port: 8888,
        pingInterval: TimeInterval(1)
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
