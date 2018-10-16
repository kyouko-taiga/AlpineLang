import AST

public struct ParseError: Error, CustomStringConvertible {

  public init(_ cause: SyntaxError, range: SourceRange? = nil) {
    self.cause = cause
    self.range = range
  }

  public let cause: SyntaxError
  public let range: SourceRange?

  public var description: String {
    return cause.description
  }

}
