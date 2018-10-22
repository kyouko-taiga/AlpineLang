import AST

public enum SyntaxError: Error, CustomStringConvertible {

  /// Occurs when parsing tuple values or signatures with duplicate labels.
  case duplicateLabel(label: String)
  /// Occurs when parsing tuple signatures with duplicate names.
  case duplicateName(name: String)
  /// Occurs when parsing empty tuple values or signatures.
  case emptyTuple
  /// Occurs when the parser fails to parse an identifier.
  case expectedIdentifier
  /// Occurs when the parser fails to parse the member of a select expression.
  case expectedMember
  /// Occurs when the parser fails to parse a statement delimiter.
  case expectedStatementDelimiter
  /// Occurs when a function is declared without a function signature.
  case invalidFunctionSignature(signature: TypeSign)
  /// Occurs when the parser unexpectedly depletes the stream.
  case unexpectedEOS
  /// Occurs when the parser encounters an unexpected token.
  case unexpectedToken(expected: String?, got: Token)

  public var description: String {
    switch self {
    case .duplicateLabel(let label):
      return "duplicate label '\(label)'"
    case .duplicateName(let name):
      return "duplicate name '\(name)'"
    case .emptyTuple:
      return "empty tuple"
    case .expectedIdentifier:
      return "expected identifier"
    case .expectedMember:
      return "expected member name following '.'"
    case .expectedStatementDelimiter:
      return "consecutive statements should be separated by ';'"
    case .invalidFunctionSignature(let signature):
      return "invalid function signature '\(signature)'"
    case .unexpectedEOS:
      return "unexpected end of stream"
    case .unexpectedToken(let expected, let got):
      return expected != nil
        ? "expected '\(expected!)', found '\(got)'"
        : "unexpected token '\(got)'"
    }
  }

}
