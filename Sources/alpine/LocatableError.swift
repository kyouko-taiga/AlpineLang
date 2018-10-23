import AST
import Parser

protocol LocatableError {

  var range: SourceRange? { get }

}

extension ASTError: LocatableError {

  var range: SourceRange? {
    return node.range
  }

}

extension ParseError: LocatableError {
}
