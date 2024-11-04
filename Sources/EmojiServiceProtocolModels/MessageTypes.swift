public enum Message: Sendable, Equatable, Codable {
  case welcome(Welcome)
  case event(Event)
  case request(Request)
  case response(Response.Result)
}

public struct Welcome: Sendable, Codable, Equatable {
  public let message: String
  
  public init(message: String) {
    self.message = message
  }
}

public struct RequestError: Sendable, Codable, Equatable, Error {
  public let reason: Reason
  public let message: String?
  
  public init(reason: Reason, message: String?) {
    self.reason = reason
    self.message = message
  }
  
  public enum Reason: Sendable, Codable, Equatable {
    /// The data provided is not a valid JSON format
    case malformedJSONResquest
  }
}
