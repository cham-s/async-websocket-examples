import CasePaths
import Foundation

// MARK: - Events Payloads

/// The current main emoji changed.
public struct EmojiDidChangedEvent: Sendable, Codable, Equatable {
  /// Value of the current emoji.
  public let newEmoji: String
  
  public init(newEmoji: String) {
    self.newEmoji = newEmoji
  }
}

// MARK: - Requests Payloads
/// Gets a random list of emojis based on the requested count.
///
/// Defaults to one if no count is specified.
public struct GetRandomEmojisRequest: Sendable, Codable, Equatable {
  public let count: Int?
  
  public init(count: Int? = nil) {
    self.count = count
  }
}

// MARK: - Responses Payloads
/// Gets a random list of emojis based on the requested count.
///
/// Defaults to one if a count is not specified.
public struct GetRandomEmojisResponse: Sendable, Codable, Equatable {
  /// A list of emojis.
  public let emojis: [String]
  
  public init(emojis: [String]) {
    self.emojis = emojis
  }
}

// MARK: - Event

/// An event coming from the server.
@CasePathable
public enum Event: Sendable, Codable, Equatable {
  /// The current main emoji did changed.
  case emojiDidChangedEvent(EmojiDidChangedEvent)
}

// MARK: - Request
/// A request to be sent to the server.
@CasePathable
public enum Request: Sendable, Codable, Equatable {
  /// Gets a random list of emojis based on the requested count.
  case getRandomEmojiList(GetRandomEmojisRequest)
  /// Starts the stream of emojis.
  case startStream
  /// Stops the stream of emojis.
  case stopStream
}

// MARK: - Response
/// A response resulting from a previous request.
@CasePathable
public enum Response: Sendable, Codable, Equatable {
  /// A list of emojis based on the requested count.
  case getRandomEmojiList(GetRandomEmojisResponse)
  /// Started the stream of emojis.
  case startStream
  /// Stopped the stream of emojis.
  case stopStream
  
  @CasePathable
  public enum Result: Sendable, Codable, Equatable {
    case succcess(Response)
    case failure(RequestError)
  }
}

