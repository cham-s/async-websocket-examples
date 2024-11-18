import AsyncWebSocketClient
import AsyncWebSocketClientLive
import AsyncWebSocketOperators

// Example Demo:
// Demonstrates the use of the listen operator focusing on the connected status
// and the text frame.
// The package provides example servers that emit text frame to launch before running the current demo.
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
