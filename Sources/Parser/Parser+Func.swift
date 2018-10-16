import AST
import Utils

extension Parser {

  /// Parses a function declaration.
  public func parseFunc() throws -> Func {
    guard let start = consume(.func)?.range.start
      else { throw unexpectedToken(expected: "func") }

    // Parse the optional name of the function.
    let name = consume(.identifier, afterMany: .newline)?.value

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
