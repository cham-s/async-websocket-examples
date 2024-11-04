// swift-tools-version: 6.0

import PackageDescription

import PackageDescription

let package = Package(
  name: "async-websocket-examples",
  platforms: [
    .iOS(.v13),
    .macOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .visionOS(.v1),
  ],
  products: [
    .executable(name: "EmojisDemo", targets: ["EmojisDemo"]),
    .executable(name: "GettingStartedDemo", targets: ["GettingStartedDemo"]),
    .executable(name: "ListenOperatorDemo", targets: ["ListenOperatorDemo"]),
    .executable(name: "LogOperatorDemo", targets: ["LogOperatorDemo"]),

    // Server Demos
    .executable(name: "EmojisServer", targets: ["EmojisServer"]),
    .executable(name: "EchoServer", targets: ["EchoServer"]),
    .executable(name: "TimeServer", targets: ["TimeServer"]),
    
    //Libraries
    .library(name: "EmojiServiceProtocolModels", targets: ["EmojiServiceProtocolModels"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.58.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.3.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "1.1.2"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.2.2"),
    .package(url: "https://github.com/pointfreeco/swift-gen.git", from: "0.4.0"),
    .package(url: "https://github.com/cham-s/async-websocket.git", from: "0.1.0-beta"),
  ],
  
  targets: [
    // MARK: - Executable Demos
    .executableTarget(
      name: "EmojisDemo",
      dependencies: [
        "EmojiServiceProtocolModels",
        .product(name: "AsyncWebSocketClient", package: "async-websocket"),
        .product(name: "AsyncWebSocketClientLive", package: "async-websocket"),
        .product(name: "AsyncWebSocketOperators", package: "async-websocket"),
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    
    .executableTarget(
      name: "GettingStartedDemo",
      dependencies: [
        .product(name: "AsyncWebSocket", package: "async-websocket"),
      ]
    ),
    
    .executableTarget(
      name: "ListenOperatorDemo",
      dependencies: [
        .product(name: "AsyncWebSocketClient", package: "async-websocket"),
        .product(name: "AsyncWebSocketClientLive", package: "async-websocket"),
        .product(name: "AsyncWebSocketOperators", package: "async-websocket"),
      ]
    ),

    .executableTarget(
      name: "LogOperatorDemo",
      dependencies: [
        .product(name: "AsyncWebSocketClient", package: "async-websocket"),
        .product(name: "AsyncWebSocketClientLive", package: "async-websocket"),
        .product(name: "AsyncWebSocketOperators", package: "async-websocket"),
      ]
    ),
    
    // MARK: Server Demos
    .executableTarget(
      name: "EmojisServer",
      dependencies: [
        "EmojiServiceProtocolModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "Gen", package: "swift-gen"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOWebSocket", package: "swift-nio"),
      ]
    ),
    
    .executableTarget(
      name: "EchoServer",
      dependencies: [
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOWebSocket", package: "swift-nio"),
      ]
    ),
    
    .executableTarget(
      name: "TimeServer",
      dependencies: [
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOWebSocket", package: "swift-nio"),
      ]
    ),
    
    .target(
      name: "EmojiServiceProtocolModels",
      dependencies: [
        .product(name: "CasePaths", package: "swift-case-paths"),
      ]
    )
  ]
)
