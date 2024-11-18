import AsyncWebSocketClient
import AsyncWebSocketClientLive
import AsyncWebSocketOperators
import Foundation

// Example Demo:
// Demonstrates the use of the log operator.
// The package provides example servers to launch before running the current demo.
// To run one of the server inside the console you have to issue the command:
// swift run name-of-the-server
// Where name-of-the-server is the chosen example server.
// for instance:
// swift run TimeServer
// swift run EchoServer

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
