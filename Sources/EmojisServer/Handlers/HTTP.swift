//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import NIOHTTP1

final class HTTPByteBufferResponsePartHandler: ChannelOutboundHandler {
  typealias OutboundIn = HTTPPart<HTTPResponseHead, ByteBuffer>
  typealias OutboundOut = HTTPServerResponsePart
  
  func write(
    context: ChannelHandlerContext,
    data: NIOAny,
    promise: EventLoopPromise<Void>?
  ) {
    print("write")
    let part = self.unwrapOutboundIn(data)
    switch part {
    case let .head(head):
      context.write(self.wrapOutboundOut(.head(head)), promise: promise)
    case let .body(body):
      context.write(self.wrapOutboundOut(.body(.byteBuffer(body))), promise: promise)
    case let .end(end):
      context.write(self.wrapOutboundOut(.end(end)), promise: promise)
    }
  }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension EmojiServer {
  
  func handleHTTPChannel(_ channel: NIOAsyncChannel<HTTPServerRequestPart, HTTPPart<HTTPResponseHead, ByteBuffer>>) async throws {
    try await channel.executeThenClose { inbound, outbound in
      for try await requestPart in inbound {
        // We're not interested in request bodies here: we're just serving up GET responses
        // to get the client to initiate a websocket request.
        guard case .head(let head) = requestPart else {
          return
        }
        
        // GETs only.
        guard case .GET = head.method else {
          try await self.respond405(writer: outbound)
          return
        }
        
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html")
        headers.add(name: "Content-Length", value: String(Self.responseBody.readableBytes))
        headers.add(name: "Connection", value: "close")
        let responseHead = HTTPResponseHead(
          version: .init(major: 1, minor: 1),
          status: .ok,
          headers: headers
        )
        
        try await outbound.write(
          contentsOf: [
            .head(responseHead),
            .body(Self.responseBody),
            .end(nil)
          ]
        )
      }
    }
  }
  
  private func respond405(writer: NIOAsyncChannelOutboundWriter<HTTPPart<HTTPResponseHead, ByteBuffer>>) async throws {
    var headers = HTTPHeaders()
    headers.add(name: "Connection", value: "close")
    headers.add(name: "Content-Length", value: "0")
    let head = HTTPResponseHead(
      version: .http1_1,
      status: .methodNotAllowed,
      headers: headers
    )
    
    try await writer.write(
      contentsOf: [
        .head(head),
        .end(nil)
      ]
    )
  }

  private static let responseBody = ByteBuffer(string: websocketResponse)
  
}

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
