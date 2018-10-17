import AST
import Utils

extension Parser {

  func parseSign() throws -> TypeSign {
    // Parse a single signature.
    var signature = try parseAtomSign()

    // Attempt to parse a of signatures.
    while true {
      // Attempt to consume the infox `or` operator.
      guard consume(.or, afterMany: .newline) != nil
        else { break }

      // Parse the next signature.
      consumeNewlines()
      let right = try parseAtomSign()
      if let union = signature as? UnionSign {
        signature = UnionSign(
          cases: union.cases + [right],
          module: module,
          range: SourceRange(from: union.cases[0].range.start, to: right.range.end))
      } else {
        signature = UnionSign(
          cases: [signature, right],
          module: module,
          range: SourceRange(from: signature.range.start, to: right.range.end))
      }
    }

    return signature
  }

  /// Parses an "atomic" type signature (i.e. that may be part of a union).
  func parseAtomSign() throws -> TypeSign {
    switch peek().kind {
    case .leftParen:
      // If the signature starts with a left parenthesis, it could be either a tuple signature, or
      // any other signature enclosed in parenthesis. We'll try to parse the latter first and fall
      // back to a tuple signature if it fails.
      let backtrackPosition = streamPosition
      let start = consume()!.range.start
      consumeNewlines()
      if let enclosed = try? parseSign() {
        // If the parsed signature is a type identifier, we may have in fact parsed the label of a
        // tuple element, in which case we should backtrack.
        consumeNewlines()
        if (enclosed is TypeIdent) && (peek().kind == .colon) {
          rewind(to: backtrackPosition)
        } else if let end = consume(.rightParen)?.range.end {
          enclosed.range = SourceRange(from: start, to: end)
          return enclosed
        } else {
          throw unexpectedToken(expected: ")")
        }
      } else {
        rewind(to: backtrackPosition)
      }

      // Parsing an enclosed signature failed, so we must be facing a tuple signature instead.
      let domain = try parseTupleSign()

      // If the next token is an arrow, we're parsing a function signature.
      if consume(.arrow, afterMany: .newline) != nil {
        let codomain = try parseSign()
        return FuncSign(
          domain: domain,
          codomain: codomain,
          module: module,
          range: SourceRange(from: domain.range.start, to: codomain.range.end))
      } else {
        return domain
      }

    case .sharp:
      return try parseTupleSign()

    case .identifier:
      return try parseTypeIdent()

    default:
      return try parseTypeIdent()
    }
  }

  /// Parses a tuple signature.
  func parseTupleSign() throws -> TupleSign {
    var start: SourceLocation? = nil
    var label: String? = nil

    // Parse the label of the signature, if any.
    if let sharp = consume(.sharp) {
      guard let identifier = consume(.identifier)
        else { throw parseFailure(.expectedIdentifier) }
      start = sharp.range.start
      label = identifier.value

      // Labeled tubple signatures may not have explicit tuple elements.
      let backtrackPosition = streamPosition
      consumeNewlines()
      if label != nil && peek().kind != .leftParen {
        rewind(to: backtrackPosition)
        return TupleSign(
          label: label,
          elements: [],
          module: module,
          range: SourceRange(from: start!, to: identifier.range.end))
      }
    }

    // Parse the elements.
    guard let listStart = consume(.leftParen)?.range.start
      else { throw unexpectedToken(expected: "(") }
    let elements = try parseList(delimitedBy: .rightParen, parsingElementWith: parseTupleElemSign)
    guard let end = consume(.rightParen)?.range.end
      else { throw unexpectedToken(expected: ")") }

    // Make sure there isn't any duplicate key.
    let duplicates = elements
      .filter     { $0.label != nil }
      .duplicates { $0.label ?? "_" }
    guard duplicates.isEmpty else {
      let element = duplicates.first!
      throw ParseError(.duplicateLabel(label: element.label!), range: element.range)
    }

    return TupleSign(
      label: label,
      elements: elements,
      module: module,
      range: SourceRange(from: start ?? listStart, to: end))
  }

  /// Parses a tuple element signature.
  func parseTupleElemSign() throws -> TupleSignElem {
    // Parse the label of the element.
    guard let label = consume(.identifier) ?? consume(.underscore)
      else { throw parseFailure(.expectedIdentifier) }

    // Consume the colon delimiting the label and its type.
    guard consume(.colon, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: "colon") }

    // Parse the type signature of the element.
    consumeNewlines()
    let signature = try parseSign()

    return TupleSignElem(
      label: label.kind == .identifier ? label.value : nil,
      signature: signature,
      module: module,
      range: SourceRange(from: label.range.start, to: signature.range.end))
  }

  /// Parses a type identifier.
  func parseTypeIdent() throws -> TypeIdent {
    guard let token = consume(.identifier)
      else { throw parseFailure(.expectedIdentifier) }
    return TypeIdent(name: token.value!, module: module, range: token.range)
  }

}
