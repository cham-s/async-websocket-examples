import EmojiServiceProtocolModels
import Foundation
import NIOFoundationCompat
import NIOCore
import NIOWebSocket

enum WebSocketHandlerEnvironment {
  typealias ChannelTools = (
    outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>,
    allocator: ByteBufferAllocator
  )
  @TaskLocal
  static var tools: ChannelTools?
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension EmojiServer {
  func handleWebSocketChannel(
    _ channel: NIOAsyncChannel<WebSocketFrame, WebSocketFrame>
  ) async throws {
    print("Establishedd a connection with:", channel.channel.remoteAddress ?? "Not identified")
    
    let message = Message.welcome(.init(message: "Welcome to the Emojis server 😃"))
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let messageData = try encoder.encode(message)
    let text = String(data: messageData, encoding: .utf8)!
    
    let buffer = channel.channel.allocator.buffer(string: text)
    let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
    
    try await channel.channel.writeAndFlush(.init(frame))
    
    try await channel.executeThenClose { inbound, outbound in
      await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          for try await frame in inbound {
            try await self.handleWebSocketFrame(
              frame,
              allocator: channel.channel.allocator,
              outbound: outbound
            )
          }
        }
      }
    }
  }
  
  private func handleWebSocketFrame(
    _ frame: WebSocketFrame,
    allocator: ByteBufferAllocator,
    outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>
  ) async throws {
    let tools = (outbound: outbound, allocator: allocator)
    
    try await WebSocketHandlerEnvironment.$tools.withValue(tools) {
      switch frame.opcode {
      case .ping:
        var frameData = frame.data
        let maskingKey = frame.maskKey
        if let maskingKey {
          frameData.webSocketUnmask(maskingKey)
        }
        
        let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
        try await outbound.write(responseFrame)
        
      case .connectionClose:
        var data = frame.unmaskedData
        let closeDataCode = data.readSlice(length: 2) ?? ByteBuffer()
        let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: closeDataCode)
        try await outbound.write(closeFrame)
        
      case .text:
        var frameData = frame.data
        let maskingKey = frame.maskKey
        if let maskingKey {
          frameData.webSocketUnmask(maskingKey)
        }
        
        let string = frameData.readString(length: frameData.readableBytes) ?? ""
        let data = string.data(using: .utf8) ?? Data()
        try await self.handleData(data)
        
      case .binary, .continuation, .pong:
        // Ignored
        break
      default:
        // Unknown at the time of writing
        break
        
      }
    }
  }
  
  private func handleData(_ data: Data) async throws {
    do {
      let message = try JSONDecoder().decode(Message.self, from: data)
      switch message {
      case let .request(request):
        try await self.handleRequest(request)
      case .response, .welcome, .event:
       // Ignore by the server side
        break
      }
    } catch {
      let response = Response.Result.failure(
        .init(
          reason: .malformedJSONResquest,
          message: "\(error)"
        )
      )
      try await self.sendMessage(.response(response))
    }
  }
  
  func sendMessage(_ message: Message) async throws {
    guard let (outbound, allocator) = WebSocketHandlerEnvironment.tools
    else { throw ServerOperationError.internalServerError }
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let messageData = try encoder.encode(message)
    let messageText = String(decoding: messageData, as: UTF8.self)
    
    let buffer = allocator.buffer(string: messageText)
    let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
    
    try await outbound.write(frame)
  }
}

enum ServerOperationError: Error {
  case internalServerError
}
