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

import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOConcurrencyHelpers
import NIOWebSocket

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension EmojiServer {
  func run() async throws {
    let channel: NIOAsyncChannel<EventLoopFuture<UpgradeResult>, Never> =
    try await ServerBootstrap(group: eventLoopGroop)
      .bind(
        host: self.host,
        port: self.port
      ) { channel in
        channel.eventLoop.makeCompletedFuture {
          let upgrader = NIOTypedWebSocketServerUpgrader<UpgradeResult>(
            shouldUpgrade: { (channel, head) in
              channel.eventLoop.makeSucceededFuture(HTTPHeaders())
            },
            upgradePipelineHandler: { (channel, _) in
              channel.eventLoop.makeCompletedFuture {
                let asyncChannel = try NIOAsyncChannel<WebSocketFrame, WebSocketFrame>(
                  wrappingChannelSynchronously: channel
                )
                return UpgradeResult.websocket(asyncChannel)
              }
            }
          )
          
          let serverUpgradeConfiguration = NIOTypedHTTPServerUpgradeConfiguration(
            upgraders: [upgrader],
            notUpgradingCompletionHandler: { channel in
              channel.eventLoop.makeCompletedFuture {
                try channel.pipeline.syncOperations.addHandler(HTTPByteBufferResponsePartHandler())
                let asyncChannel = try NIOAsyncChannel<
                  HTTPServerRequestPart,
                  HTTPPart<HTTPResponseHead, ByteBuffer>
                >(wrappingChannelSynchronously: channel)
                return UpgradeResult.notUpgraded(asyncChannel)
              }
            }
          )
          
          let negotiationResultFuture = try channel.pipeline
            .syncOperations
            .configureUpgradableHTTPServerPipeline(
              configuration: .init(upgradeConfiguration: serverUpgradeConfiguration)
            )
          
          return negotiationResultFuture
        }
      }
    
    print("😀 Running the Emojis server: Listening on \(self.host) port: \(self.port)")
    
    try await withThrowingDiscardingTaskGroup { group in
      try await channel.executeThenClose { inbound in
        for try await upgradeResult in inbound {
          group.addTask {
            try await self.handleUpgradeResult(upgradeResult)
          }
        }
      }
    }
  }
    
  private func handleUpgradeResult(
    _ upgradeResult: EventLoopFuture<UpgradeResult>
  ) async throws {
    do {
      switch try await upgradeResult.get() {
      case let .websocket(webSocketChannel):
        try await self.handleWebSocketChannel(webSocketChannel)
      case let .notUpgraded(httpChannel):
        try await self.handleHTTPChannel(httpChannel)
      }
    } catch {
      print("Hit error: \(error)")
    }
  }
}
