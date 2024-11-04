//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import CustomDump
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
#if os(macOS) ||  os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import Foundation
#endif

extension ChannelHandlerContext: @unchecked @retroactive Sendable { }

let websocketResponse = """
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Swift NIO WebSocket Test Page</title>
    <script>
        var wsconnection = new WebSocket("ws://localhost:8888/websocket");
        wsconnection.onmessage = function (msg) {
            var element = document.createElement("p");
            element.innerHTML = msg.data;

            var textDiv = document.getElementById("websocket-stream");
            textDiv.insertBefore(element, null);
        };
    </script>
  </head>
  <body>
    <h1>WebSocket Stream</h1>
    <div id="websocket-stream"></div>
  </body>
</html>
"""

private final class HTTPHandler: @unchecked Sendable, ChannelInboundHandler, RemovableChannelHandler {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart
  
  private var responseBody: ByteBuffer!
  
  func handlerAdded(context: ChannelHandlerContext) {
    self.responseBody = context.channel.allocator.buffer(string: websocketResponse)
  }
  
  func handlerRemoved(context: ChannelHandlerContext) {
    self.responseBody = nil
  }
  
  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let reqPart = self.unwrapInboundIn(data)
    
    // We're not interested in request bodies here: we're just serving up GET responses
    // to get the client to initiate a websocket request.
    guard case .head(let head) = reqPart else {
      return
    }
    
    // GETs only.
    guard case .GET = head.method else {
      self.respond405(context: context)
      return
    }
    
    var headers = HTTPHeaders()
    headers.add(name: "Content-Type", value: "text/html")
    headers.add(name: "Content-Length", value: String(self.responseBody.readableBytes))
    headers.add(name: "Connection", value: "close")
    let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1),
                                        status: .ok,
                                        headers: headers)
    context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
    context.write(self.wrapOutboundOut(.body(.byteBuffer(self.responseBody))), promise: nil)
    context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
      context.close(promise: nil)
    }
    context.flush()
  }
  
  private func respond405(context: ChannelHandlerContext) {
    var headers = HTTPHeaders()
    headers.add(name: "Connection", value: "close")
    headers.add(name: "Content-Length", value: "0")
    let head = HTTPResponseHead(version: .http1_1,
                                status: .methodNotAllowed,
                                headers: headers)
    context.write(self.wrapOutboundOut(.head(head)), promise: nil)
    context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
      context.close(promise: nil)
    }
    context.flush()
  }
}

extension String {
  fileprivate func received() -> String {
    return "[Received \(self)]"
  }
}

extension WebSocketOpcode {
  fileprivate var title: String {
    switch self {
    case .binary: return "binary".received()
    case .continuation: return "continuation".received()
    case .connectionClose: return "connectionClose".received()
    case .ping: return "ping".received()
    case .pong: return "pong".received()
    case .text: return "text".received()
    default: return "unknown control frame".received()
    }
  }
}

private final class WebSocketEchoHandler: ChannelInboundHandler {
  typealias InboundIn = WebSocketFrame
  typealias OutboundOut = WebSocketFrame
  
  private var awaitingClose: Bool = false
  
  public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let frame = self.unwrapInboundIn(data)
    self.frame(context: context, frame: frame)
  }
  
  public func channelReadComplete(context: ChannelHandlerContext) {
    context.flush()
  }
  
  private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
    // Handle a received close frame. In websockets, we're just going to send the close
    // frame and then close, unless we already sent our own close frame.
    if awaitingClose {
      // Cool, we started the close and were waiting for the user. We're done.
      context.close(promise: nil)
    } else {
      let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: frame.unmaskedData)
     context.writeAndFlush(self.wrapOutboundOut(closeFrame))
        .whenComplete { _ in context.close(promise: nil) }
    }
  }
  
  private func pong(context: ChannelHandlerContext, frame: WebSocketFrame) {
    var frameData = frame.data
    let maskingKey = frame.maskKey
    
    if let maskingKey = maskingKey {
      frameData.webSocketUnmask(maskingKey)
    }
    
    customDump(frameData, name: "[Received ping]")
    let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
    context.write(self.wrapOutboundOut(responseFrame), promise: nil)
  }
  
  private func frame(
    context: ChannelHandlerContext,
    frame: WebSocketFrame
  ) {
    var frameData = frame.data
    let maskingKey = frame.maskKey
    
    if let maskingKey = maskingKey {
      frameData.webSocketUnmask(maskingKey)
    }
    
    customDump(frameData, name: frame.opcode.title)
    
    switch frame.opcode {
    case .connectionClose:
      self.receivedClose(context: context, frame: frame)
    case .ping:
      self.pong(context: context, frame: frame)
      
    case .text, .binary, .pong, .continuation:
      let responseFrame = WebSocketFrame(fin: true, opcode: frame.opcode, data: frameData)
      context.write(self.wrapOutboundOut(responseFrame), promise: nil)
      
    default:
      let responseFrame = WebSocketFrame(fin: true, opcode: .binary, data: frameData)
      context.write(self.wrapOutboundOut(responseFrame), promise: nil)
    }
  }
  
  private func closeOnError(context: ChannelHandlerContext) {
    // We have hit an error, we want to close. We do that by sending a close frame and then
    // shutting down the write side of the connection.
    var data = context.channel.allocator.buffer(capacity: 2)
    data.write(webSocketErrorCode: .protocolError)
    let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
    context.write(self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
      context.close(mode: .output, promise: nil)
    }
    awaitingClose = true
  }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

let upgrader = NIOWebSocketServerUpgrader(shouldUpgrade: { (channel: Channel, head: HTTPRequestHead) in channel.eventLoop.makeSucceededFuture(HTTPHeaders()) },
                                          upgradePipelineHandler: { (channel: Channel, _: HTTPRequestHead) in
  channel.pipeline.addHandler(WebSocketEchoHandler())
})

let bootstrap = ServerBootstrap(group: group)
// Specify backlog and enable SO_REUSEADDR for the server itself
  .serverChannelOption(ChannelOptions.backlog, value: 256)
  .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

// Set the handlers that are applied to the accepted Channels
  .childChannelInitializer { channel in
    let httpHandler = HTTPHandler()
    let config: NIOHTTPServerUpgradeConfiguration = (
      upgraders: [ upgrader ],
      completionHandler: { _ in
        channel.pipeline.removeHandler(httpHandler, promise: nil)
      }
    )
    return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
      channel.pipeline.addHandler(httpHandler)
    }
  }

// Enable SO_REUSEADDR for the accepted Channels
  .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

defer {
  try! group.syncShutdownGracefully()
}

// First argument is the program path
let arguments = CommandLine.arguments
let arg1 = arguments.dropFirst().first
let arg2 = arguments.dropFirst(2).first

let defaultHost = "localhost"
let defaultPort = 8888

enum BindTo {
  case ip(host: String, port: Int)
  case unixDomainSocket(path: String)
}

let bindTarget: BindTo
switch (arg1, arg1.flatMap(Int.init), arg2.flatMap(Int.init)) {
case (.some(let h), _ , .some(let p)):
  /* we got two arguments, let's interpret that as host and port */
  bindTarget = .ip(host: h, port: p)
  
case (let portString?, .none, _):
  // Couldn't parse as number, expecting unix domain socket path.
  bindTarget = .unixDomainSocket(path: portString)
  
case (_, let p?, _):
  // Only one argument --> port.
  bindTarget = .ip(host: defaultHost, port: p)
  
default:
  bindTarget = .ip(host: defaultHost, port: defaultPort)
}

let channel = try { () -> Channel in
  switch bindTarget {
  case .ip(let host, let port):
    return try bootstrap.bind(host: host, port: port).wait()
  case .unixDomainSocket(let path):
    return try bootstrap.bind(unixDomainSocketPath: path).wait()
  }
}()

guard let localAddress = channel.localAddress else {
  fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
}

if case let .ip(host, port) = bindTarget {
  print("Server started and listening on \(host):\(port)")
} else {
  print("Server started and listening on \(localAddress)")
}


// This will never unblock as we don't close the ServerChannel
try channel.closeFuture.wait()

print("Server closed")
