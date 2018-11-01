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
        consumeNewlines()
        let next = peek().kind

        if next == .comma {
          // If the next token is a comma, we parsed the first element of a tuple signature.
          rewind(to: backtrackPosition)
        } else if (enclosed is TypeIdent) && ((next == .colon) || (next == .identifier)) {
          // If the parsed signature is an identifier, and the next token is either a colon or
          // another identifier, we parsed the label of the first element of a tuple signature.
          rewind(to: backtrackPosition)
        } else if let end = consume(.rightParen)?.range.end {
          if consume(.arrow, afterMany: .newline) != nil {
            // If we parsed a right parenthesis followed by an arrow, we parsed the domain of a
            // function signature.
            rewind(to: backtrackPosition)
          } else {
            enclosed.range = SourceRange(from: start, to: end)
            return enclosed
          }
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
    var label: String? = nil
    var start: SourceLocation? = nil

    // Parse the label of the signature, if any.
    if let sharp = consume(.sharp) {
      let (value, range) = try parseLabel()
      start = sharp.range.start
      label = value

      // Labeled tuple signatures may not have explicit tuple elements.
      let backtrackPosition = streamPosition
      consumeNewlines()
      if peek().kind != .leftParen {
        rewind(to: backtrackPosition)
        return TupleSign(
          label: label,
          elements: [],
          module: module,
          range: SourceRange(from: start!, to: range.end))
      }
    }

    // Parse the elements.
    guard let listStart = consume(.leftParen)?.range.start
      else { throw unexpectedToken(expected: "(") }
    let elements = try parseList(delimitedBy: .rightParen, parsingElementWith: parseTupleElemSign)
    guard let end = consume(.rightParen)?.range.end
      else { throw unexpectedToken(expected: ")") }

    // Make sure there isn't any duplicate key.
    let duplicateLabels = elements
      .filter     { $0.label != nil }
      .duplicates { $0.label ?? "_" }
    guard duplicateLabels.isEmpty else {
      let element = duplicateLabels.first!
      throw ParseError(.duplicateLabel(label: element.label!), range: element.range)
    }

    let duplicateNames = elements
      .filter     { $0.name != nil }
      .duplicates { $0.name ?? "_" }
    guard duplicateNames.isEmpty else {
      let element = duplicateNames.first!
      throw ParseError(.duplicateName(name: element.name!), range: element.range)
    }

    return TupleSign(
      label: label,
      elements: elements,
      module: module,
      range: SourceRange(from: start ?? listStart, to: end))
  }

  /// Parses a tuple element signature.
  func parseTupleElemSign() throws -> TupleSignElem {

    // Note: Tuple element signatures are a bit tricky to parse, as they have various syntaxes. They
    // can be defined with a label and/or a name plus a signature, or with a signature, without any
    // label. Since an identifier could be parsed as a type identifier, we first need to identify
    // whether the first identifier(s) we encounter are part of the API or the signature.

    let backtrackPosition = streamPosition

    if let first = consume(.underscore) ?? consume(if: { $0.isLabel }) {
      consumeNewlines()

      // If we could parse a first identifier, there might be a formal name as well.
      if let second = consume(if: { $0.isLabel }) {
        // Parsing two names (or `_` + a name) means both must be part of the API. Hence the next
        // tokens should be a colon followed by the signature of the element.
        guard consume(.colon, afterMany: .newline) != nil
          else { throw unexpectedToken(expected: ":") }
        consumeNewlines()
        let signature = try parseSign()

        return TupleSignElem(
          label: first.asLabel,
          name: second.asLabel,
          signature: signature,
          module: module,
          range: SourceRange(from: first.range.start, to: signature.range.end))
      } else if consume(.colon, afterMany: .newline) != nil {
        // Parsing a name + a colon means it was part of the API. Hence the next tokens must
        // represent the signature of the element.
        consumeNewlines()
        let signature = try parseSign()

        return TupleSignElem(
          label: first.asLabel,
          name: first.asLabel,
          signature: signature,
          module: module,
          range: SourceRange(from: first.range.start, to: signature.range.end))
      } else {
        // We parsed a single name, but failed to parse colons, so we should go back and parse the
        // name as a type identifier instead.
        rewind(to: backtrackPosition)
      }
    }

    // We failed to parse an API, so the element must be made of a type signature only.
    let signature = try parseSign()
    return TupleSignElem(
      label: nil,
      name: nil,
      signature: signature,
      module: module,
      range: signature.range)
  }

  /// Parses a type identifier.
  func parseTypeIdent() throws -> TypeIdent {
    guard let token = consume(.identifier)
      else { throw parseFailure(.expectedIdentifier) }
    return TypeIdent(name: token.value!, module: module, range: token.range)
  }

}
