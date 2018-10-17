import AST

/// Enumerates the kinds of tokens.
public enum TokenKind: String {

  // MARK: Literals

  case bool
  case integer
  case float
  case string

  // MARK: Identifiers

  case identifier
  case underscore

  // MARK: Operators

  case not
  case and
  case or
  case add
  case sub
  case mul
  case div
  case mod
  case lt
  case le
  case ge
  case gt
  case eq
  case ne
  case arrow
  case thickArrow

  case dot
  case comma
  case colon
  case doubleColon
  case semicolon
  case sharp
  case exclamationMark
  case questionMark
  case ellipsis
  case newline
  case eof

  case leftParen
  case rightParen
  case leftBrace
  case rightBrace
  case leftBracket
  case rightBracket

  // MARK: Keywords

  case `let`
  case `func`
  case type
  case `if`
  case `then`
  case `else`
  case match
  case with

  // MARK: Error tokens

  case unknown
  case unterminatedBlockComment
  case unterminatedStringLiteral

}

/// Represents a token.
public struct Token {

  public init(kind: TokenKind, value: String? = nil, range: SourceRange) {
    self.kind = kind
    self.value = value
    self.range = range
  }

  /// Whether or not the token is a statement delimiter.
  public var isStatementDelimiter: Bool {
    return kind == .newline || kind == .semicolon
  }

  /// Whether or not the token is an prefix operator.
  public var isPrefixOperator: Bool {
    return asPrefixOperator != nil
  }

  /// The token as a prefix operator.
  public var asPrefixOperator: PrefixOperator? {
    return PrefixOperator(rawValue: kind.rawValue)
  }

  /// Whether or not the token is an infix operator.
  public var isInfixOperator: Bool {
    return asInfixOperator != nil
  }

  /// The token as an infix operator.
  public var asInfixOperator: InfixOperator? {
    return InfixOperator(rawValue: kind.rawValue)
  }

  /// The kind of the token.
  public let kind: TokenKind
  /// The optional value of the token.
  public let value: String?
  /// The range of characters that compose the token in the source file.
  public let range: SourceRange

}

extension Token: Equatable {

  public static func == (lhs: Token, rhs: Token) -> Bool {
    return (lhs.kind == rhs.kind) && (lhs.value == rhs.value) && (lhs.range == rhs.range)
  }

}

extension Token: CustomStringConvertible {

  public var description: String {
    return kind.rawValue
  }

}
