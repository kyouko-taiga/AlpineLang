import AST

extension Parser {

  /// Parses an expression.
  ///
  /// Because the parser is implemented as a recursive descent parser, a particular attention must
  /// be made as to how expressions can be parsed witout triggering infinite recursions, due to the
  /// left-recursion of the related production rules.
  public func parseExpr() throws -> Expr {
    // Parse an atom.
    var expression = try parseAtom()

    // Attempt to parse the remainder of a binary expression.
    while true {
      // Attempt to consume an infix operator.
      let backtrackPosition = streamPosition
      consumeNewlines()
      guard peek().isInfixOperator else {
        rewind(to: backtrackPosition)
        break
      }

      // Parse an infix operator.
      let opToken = consume()!
      let opInfix = opToken.asInfixOperator!
      let opIdent = Ident(name: opInfix.description, module: module, range: opToken.range)

      // If an infix operator could be consumed, then we MUST parse a right operand.
      consumeNewlines()
      let rightOperand = try parseAtom()

      // If the left operand is a binary expression, we should check the precedence of its operator
      // and potentially reorder the operands.
      if let binary = expression as? Binary, binary.precedence < opInfix.precedence {
        let left = binary.left
        let right = Binary(
          op: opIdent, precedence: opInfix.precedence, left: binary.right, right: rightOperand,
          module: module,
          range: SourceRange(from: binary.right.range.start, to: rightOperand.range.end))
        expression = Binary(
          op: binary.op, precedence: binary.precedence, left: left, right: right,
          module: module,
          range: SourceRange(from: left.range.start, to: right.range.end))
      } else {
        expression = Binary(
          op: opIdent, precedence: opInfix.precedence, left: expression, right: rightOperand,
          module: module,
          range: SourceRange(from: expression.range.start, to: rightOperand.range.end))
      }
    }

    return expression
  }

  /// Parses an atom.
  func parseAtom() throws -> Expr {
    let token = peek()

    var expression: Expr
    switch token.kind {
    case .integer:
      consume()
      expression = Scalar(value: Int(token.value!)!, module: module, range: token.range)
    case .float:
      consume()
      expression = Scalar(value: Double(token.value!)!, module: module, range: token.range)
    case .string:
      consume()
      expression = Scalar(value: token.value!, module: module, range: token.range)
    case .bool:
      consume()
      expression = Scalar(value: token.value == "true", module: module, range: token.range)

    case _ where token.isPrefixOperator:
      expression = try parseUnary()
    case .sharp:
      expression = try parseTuple()
    case .identifier:
      expression = try parseIdent()
    case .if:
      expression = try parseIf()
    case .match:
      expression = try parseMatch()
    case .let:
      expression = try parseLetBinding()
    case .func:
      expression = try parseFunc()

    case .leftParen:
      // If the expression starts with a left parenthesis, it could be either a tuple, or any other
      // expression enclosed in parenthesis. We'll try to parse the latter first and fall back to a
      // tuple if it fails.
      let backtrackPosition = streamPosition
      let start = consume()!.range.start
      consumeNewlines()
      if let enclosed = try? parseExpr() {
        // If the parsed expression is an identifier, we may have in fact parsed the label of a
        // tuple element, in which case we should backtrack.
        consumeNewlines()
        if (peek().kind == .comma) || (enclosed is Ident) && (peek().kind == .colon) {
          rewind(to: backtrackPosition)
          expression = try parseTuple()
        } else if let end = consume(.rightParen)?.range.end {
          enclosed.range = SourceRange(from: start, to: end)
          expression = enclosed
        } else {
          throw unexpectedToken(expected: ")")
        }
      } else {
        rewind(to: backtrackPosition)
        expression = try parseTuple()
      }

    default:
      throw unexpectedToken(expected: "expression")
    }

    // Parse optional trailers.
    trailer:while true {
      // Although it wouldn't make the grammar ambiguous otherwise, notice that we require such
      // call trailers to start at the same line. The rationale is that it doing otherwise could
      // easily make some portions of code *look* ambiguous.
      if consume(.leftParen) != nil {
        let args = try parseList(delimitedBy: .rightParen, parsingElementWith: parseArg)

        // Consume the delimiter of the list.
        guard let endToken = consume(.rightParen)
          else { throw unexpectedToken(expected: ")") }

        expression = Call(
          callee: expression,
          arguments: args,
          module: module,
          range: SourceRange(from: expression.range.start, to: endToken.range.end))
        continue trailer
      }

      // Consuming new lines here allow us to parse select expressions split over several lines.
      // However, if the next consumable token isn't a dot, we need to backtrack, so as to avoid
      // consuming possibly significant new lines.
      let backtrackPosition = streamPosition
      if consume(.dot, afterMany: .newline) != nil {
        // Although it wouldn't make the grammar ambiguous otherwise, notice that we require the
        // selected identifier or index to be on the same line.
        guard let owneeToken = consume(.identifier) ?? consume(.integer)
          else { throw parseFailure(.expectedMember) }
        let ownee = owneeToken.kind == .identifier
          ? Select.Ownee.label(owneeToken.value!)
          : Select.Ownee.index(Int(owneeToken.value!)!)

        expression = Select(
          owner: expression,
          ownee: ownee,
          module: module,
          range: SourceRange(from: expression.range.start, to: owneeToken.range.end))
        continue trailer
      }

      // No more trailer to parse.
      rewind(to: backtrackPosition)
      break
    }

    return expression
  }

  /// Parses an unary expression.
  func parseUnary() throws -> Unary {
    guard let op = consume(), op.isPrefixOperator
      else { throw unexpectedToken(expected: "unary operator") }

    let opIdent = Ident(name: op.asPrefixOperator!.description, module: module, range: op.range)
    let operand = try parseExpr()
    return Unary(
      op: opIdent,
      operand: operand,
      module: module,
      range: SourceRange(from: op.range.start, to: operand.range.end))
  }

  /// Parses an identifier.
  func parseIdent() throws -> Ident {
    guard let token = consume(.identifier)
      else { throw parseFailure(.expectedIdentifier) }
    return Ident(name: token.value!, module: module, range: token.range)
  }

  /// Parses a conditional expression.
  func parseIf() throws -> If {
    guard let startToken = consume(.if)
      else { throw unexpectedToken(expected: "if") }

    // Parse the condition.
    consumeNewlines()
    let condition = try parseExpr()

    // Parse the "then" expression.
    guard consume(.then, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: "then") }
    consumeNewlines()
    let thenExpr = try parseExpr()

    // Parse the "else" expression.
    guard consume(.else, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: "else") }
    consumeNewlines()
    let elseExpr = try parseExpr()

    return If(
      condition: condition,
      thenExpr: thenExpr,
      elseExpr: elseExpr,
      module: module,
      range: SourceRange(from: startToken.range.start, to: elseExpr.range.end))
  }

  /// Parses a match expression.
  func parseMatch() throws -> Match {
    guard let start = consume(.match)?.range.start
      else { throw unexpectedToken(expected: "match") }

    // Parse the the subject.
    consumeNewlines()
    let subject = try parseExpr()

    // Make sure there's at least one match case to parse.
    consumeNewlines()
    guard peek().kind == .with
      else { throw unexpectedToken(expected: "with") }

    // Parse the match cases.
    var cases: [MatchCase] = []
    while true {
      // Parse a single case.
      cases.append(try parseMatchCase())

      // Check if there're still other cases to parse.
      let backtrackPosition = streamPosition
      consumeNewlines()
      if peek().kind == .with {
        continue
      }

      // There are no more cases to consume, so we can return the match we've parsed.
      rewind(to: backtrackPosition)
      break
    }

    return Match(
      subject: subject,
      cases: cases,
      module: module,
      range: SourceRange(from: start, to: cases.last!.range.end))
  }

  /// Parses a match case.
  func parseMatchCase() throws -> MatchCase {
    guard let start = consume(.with)?.range.start
      else { throw unexpectedToken(expected: "with") }

    // Parse the pattern.
    consumeNewlines()
    let pattern = try parseExpr()

    guard consume(.doubleColon, afterMany: .newline) != nil
      else { throw unexpectedToken(expected: "::") }

    // Parse the value.
    consumeNewlines()
    let value = try parseExpr()

    return MatchCase(
      pattern: pattern,
      value: value,
      module: module,
      range: SourceRange(from: start, to: value.range.end))
  }

  /// Parses a variable binding.
  func parseLetBinding() throws -> LetBinding {
    guard let start = consume(.let)?.range.start
      else { throw unexpectedToken(expected: "let") }
    guard let name = consume(.identifier, afterMany: .newline)
      else { throw parseFailure(.expectedIdentifier) }

    return LetBinding(
      name: name.value!,
      module: module,
      range: SourceRange(from: start, to: name.range.end))
  }

  /// Parses a call argument.
  func parseArg() throws -> Arg {
    var label: String? = nil
    var start: SourceLocation? = nil

    // Parse the optional label of the argument.
    let backtrackPosition = streamPosition
    if let (value, range) = try? parseLabel() {
      if consume(.colon, afterMany: .newline) == nil {
        rewind(to: backtrackPosition)
      } else {
        label = value
        start = range.start
      }
    }

    // Parse the argument's value.
    let value = try parseExpr()
    return Arg(
      label: label,
      value: value,
      module: module,
      range: SourceRange(from: start ?? value.range.start, to: value.range.end))
  }

  /// Parses a tuple.
  func parseTuple() throws -> Tuple {
    var label: String? = nil
    var start: SourceLocation? = nil

    // Parse the label of the tuple, if any.
    if let sharp = consume(.sharp) {
      let (value, range) = try parseLabel()
      start = sharp.range.start
      label = value

      // Labeled tuples may not have explicit tuple elements.
      let backtrackPosition = streamPosition
      consumeNewlines()
      if peek().kind != .leftParen {
        rewind(to: backtrackPosition)
        return Tuple(
          label: label,
          elements: [],
          module: module,
          range: SourceRange(from: start!, to: range.end))
      }
    }

    // Parse the elements.
    guard let listStart = consume(.leftParen)?.range.start
      else { throw unexpectedToken(expected: "(") }
    let elements = try parseList(delimitedBy: .rightParen, parsingElementWith: parseTupleElem)
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

    return Tuple(
      label: label,
      elements: elements,
      module: module,
      range: SourceRange(from: start ?? listStart, to: end))
  }

  /// Parses a tuple element.
  func parseTupleElem() throws -> TupleElem {
    var label: String? = nil
    var start: SourceLocation? = nil

    // Parse the optional label of the argument.
    let backtrackPosition = streamPosition
    if let (value, range) = try? parseLabel() {
      if consume(.colon, afterMany: .newline) == nil {
        rewind(to: backtrackPosition)
      } else {
        label = value
        start = range.start
      }
    }

    // Parse the elements's value.
    let value = try parseExpr()
    return TupleElem(
      label: label,
      value: value,
      module: module,
      range: SourceRange(from: start ?? value.range.start, to: value.range.end))
  }

  /// Parses a label
  func parseLabel() throws -> (value: String, range: SourceRange) {
    if let token = consume(if: { $0.isLabel }) {
      return (token.asLabel!, token.range)
    } else {
      throw parseFailure(.expectedIdentifier)
    }
  }

}
