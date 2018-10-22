import AST
import Utils

extension Parser {

  /// Parses a function declaration.
  public func parseFunc() throws -> Func {
    guard let start = consume(.func)?.range.start
      else { throw unexpectedToken(expected: "func") }

    // Parse the optional name of operator of the function.
    let name: String?
    let backtrackPosition = streamPosition
    consumeNewlines()
    switch peek() {
    case let token where token.isPrefixOperator:
      name = consume()!.asPrefixOperator?.description
    case let token where token.isInfixOperator:
      name = consume()!.asInfixOperator?.description
    case let token where token.kind == .identifier:
      name = consume()!.value
    default:
      rewind(to: backtrackPosition)
      name = nil
    }

    // Parse the signature of the function.
    consumeNewlines()
    let signature = try parseSign()
    guard signature is FuncSign
      else { throw parseFailure(.invalidFunctionSignature(signature: signature)) }

    guard consume(.doubleColon, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: "::") }

    // Parse the body of the function.
    consumeNewlines()
    let body = try parseExpr()

    return Func(
      name: name,
      signature: signature as! FuncSign,
      body: body,
      module: module,
      range: SourceRange(from: start, to: body.range.end))
  }

}
