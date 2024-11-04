import Dependencies
import DependenciesMacros
@preconcurrency import Gen

@DependencyClient
/// A generator used to generate emojis.
struct EmojiGenerator {
  var singleOne: @Sendable () -> String = { "👍" }
  var list: @Sendable (_ count: Int) -> [String] = {_ in [] }
}

extension EmojiGenerator: DependencyKey {
  static var liveValue: Self {
    let emoji = Gen.int(in: 0x1F30D...0x1F4B2)
      .map { String(Character(UnicodeScalar($0) ?? "?")) }
    
    return Self(
      singleOne: { emoji.run() },
      list: { count in
        let count = count > 0 ? count: 1
        return emoji.array(of: .always(count)).run()
      }
    )
  }
}
