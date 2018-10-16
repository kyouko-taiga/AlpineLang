import AST
import Utils

extension Parser {

  /// Parses a type alias declaration.
  public func parseType() throws -> TypeAlias {
    guard let start = consume(.type)?.range.start
      else { throw unexpectedToken(expected: "type") }
    guard let name = consume(.identifier, afterMany: .newline)?.value
      else { throw parseFailure(.expectedIdentifier) }
    guard consume(.doubleColon, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: "::") }

    // Parse the signature of the alias.
    consumeNewlines()
    let signature = try parseSign()

    return TypeAlias(
      name: name,
      signature: signature,
      module: module,
      range: SourceRange(from: start, to: signature.range.end))
  }

}
