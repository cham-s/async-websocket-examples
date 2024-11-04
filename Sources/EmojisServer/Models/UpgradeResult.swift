import NIOCore
import NIOHTTP1
import NIOWebSocket

enum UpgradeResult {
  case websocket(NIOAsyncChannel<WebSocketFrame, WebSocketFrame>)
  case notUpgraded(NIOAsyncChannel<HTTPServerRequestPart, HTTPPart<HTTPResponseHead, ByteBuffer>>)
}
