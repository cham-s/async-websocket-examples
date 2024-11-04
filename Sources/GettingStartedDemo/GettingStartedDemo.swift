import AsyncWebSocket
import Foundation

// Example Demo:
//  - Opens up a connection with a local server
//  - Starts listening for connection events.
//  - Starts listening for incoming frames.
//  - Sends frames to the server.
//
// ⚠️ Let's make sure we have the local server application running before running GettingStartedDemo.
//
// There are two demo servers for this demo:
//  - EchoServer: Echoes frames sent by a client.
//  - TimeServer: Sends the current server Date/Time with an interval of second.
//
// Running on XCode:
//  - Change the current target scheme by pressing Control+0 then type EchoServer or TimeServer then press Enter.
//  - Press the play ▶️ button.
//    The server should be running with the output `Server started and listening on localhost:8888` on the console.
//
//  - Now to run the demo app at the same time.
//      Switch to the GettingStartedDemo target by pressing Control+0 then type GettingStartedDemo then press Enter.
//  - Press the play ▶️ button.
//  - To switch between a scheme specific output console display click on the bar below where the name of the current scheme is displayed
//    then select the desired one.
//
//  - To stop any of the running app (server or client) press the stop ⏹️ button XCode will ask you to choose which one to stop.
//
// Running on the terminal console:
// - Make sure to be inside the package folder.
// - Before running make sure the app is not already running elsewhere. Otherwise an `already in use address` error will appear.
// - Run the following command `swift run EchoServer` or `swift run TimeServer`.
//   The server should be running with the output `Server started and listening on localhost:8888` on the console.
//
//  - Now to run the demo app at the same time.
//  - Because the current console has the server listening for event comming from a client, let's open a new terminal window.
//  - Make sure to be inside the package folder.
//  - Run the following command `swift run GettingStartedDemo`
//    The console should log frames (responses/events) coming from the the server.
//
//  - To stop any of the running app (server or client) press Control-C.

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

