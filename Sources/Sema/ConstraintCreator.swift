import AST

public final class ConstraintCreator: ASTVisitor, SAPass {

  public init(context: ASTContext) {
    self.context = context
  }

  public func visit(_ node: Func) throws {
    let funcType = node.type as! FunctionType
    let signType = read(signature: node.signature)
    context.add(
      constraint: .equality(t: funcType, u: signType, at: .location(node, .signature)))

    try visit(node.body)
    context.add(
      constraint: .conformance(
        t: node.body.type!, u: funcType.codomain, at: .location(node, .body)))
  }

  /// The AST context.
  public let context: ASTContext

  private func read(signature: TypeSign) -> TypeBase {
    switch signature {
    case let s as FuncSign : return read(signature: s)
    case let s as TupleSign: return read(signature: s)
    case let s as TypeIdent: return read(signature: s)
    case let s as UnionSign: return read(signature: s)
    default:
      fatalError("unreachable")
    }
  }

  public func visit(_ node: TypeAlias) throws {
    guard let t = node.symbol?.type
      else { return }
    assert(t is Metatype)

    let u = read(signature: node.signature).metatype
    context.add(constraint: .equality(t: t, u: u, at: .location(node, .signature)))
  }

  public func visit(_ node: If) throws {
    // The condition of a conditional expression is always boolean.
    try visit(node.condition)
    context.add(
      constraint: .equality(t: node.condition.type!, u: BuiltinType.bool, at: .location(node, .condition)))

    // Both the then and else expressions must have a type compatible with that of the entire
    // conditional expression, which is unknown at this point. Note however that both branches may
    // have unrelated types, as long as those are covariant to that of the expression itself.
    node.type = TypeVariable()
    try visit(node.thenExpr)
    context.add(
      constraint: .conformance(t: node.thenExpr.type!, u: node.type!, at: .location(node, .then)))
    try visit(node.elseExpr)
    context.add(
      constraint: .conformance(t: node.elseExpr.type!, u: node.type!, at: .location(node, .else)))
  }

  public func visit(_ node: Match) throws {
    // First, we need to create the type constraints for the match subject.
    try visit(node.subject)

    node.type = TypeVariable()
    for (i, matchCase) in node.cases.enumerated() {
      try visit(matchCase)

      // All match case patterns must be compatible with the match subject.
      context.add(constraint: .conformance(
        t: matchCase.pattern.type!,
        u: node.subject.type!,
        at: .location(node, .matchPattern(i))))

      // Just like for the case of conditional expressions, all match case must be compatible with
      // the type of match expression itself, unknown at this point. Note that cases may have
      // unrelated types, as long as those are covariant to that of the expression itself.
      context.add(constraint: .conformance(
        t: matchCase.type!,
        u: node.type!,
        at: .location(node, .matchValue(i))))
    }

  }

  public func visit(_ node: MatchCase) throws {
    try visit(node.pattern)
    try visit(node.value)
    node.type = node.value.type
  }

  public func visit(_ node: Binary) throws {
    // A binary expression is the same as a call expression. Therefore its type should be infered in
    // a similar fashion.
    let domain = context.getTupleType(
      label: nil,
      elements: [
        TupleTypeElem(label: nil, type: TypeVariable()),
        TupleTypeElem(label: nil, type: TypeVariable()),
      ])

    try visit(node.left)
    context.add(constraint: .conformance(
      t: node.left.type!,
      u: domain.elements[0].type,
      at: .location(node, .tuple) + .element(0)))

    try visit(node.right)
    context.add(constraint: .conformance(
      t: node.right.type!,
      u: domain.elements[1].type,
      at: .location(node, .tuple) + .element(1)))

    node.type = TypeVariable()
    let funcType = context.getFunctionType(from: domain, to: node.type!)

    try visit(node.op)
    context.add(
      constraint: .equality(t: node.op.type!, u: funcType, at: .location(node, .call)))
  }

  public func visit(_ node: Unary) throws {
    // An unary expression is the same as a call expression. Therefore its type should be infered in
    // a similar fashion.
    let domain = context.getTupleType(
      label: nil,
      elements: [TupleTypeElem(label: nil, type: TypeVariable())])

    try visit(node.operand)
    context.add(constraint: .conformance(
      t: node.operand.type!,
      u: domain.elements[0].type,
      at: .location(node, .tuple) + .element(0)))

    node.type = TypeVariable()
    let funcType = context.getFunctionType(from: domain, to: node.type!)

    try visit(node.op)
    context.add(
      constraint: .equality(t: node.op.type!, u: funcType, at: .location(node, .call)))
  }

  public func visit(_ node: Call) throws {
    // Due to the grammar being ambiguous, call expressions whose callee is an identifier are
    // indistinguishable from labeled tuples at this point, so we need to handle both situations
    // here. In both cases, we handle the list of arguments (or tuple elements) by building the
    // supposed type of the tuple they represent.
    let elements = node.arguments.map { TupleTypeElem(label: $0.label, type: TypeVariable()) }
    for (i, (arg, elem)) in zip(node.arguments, elements).enumerated() {
      try visit(arg)
      context.add(
        constraint: .conformance(t: arg.type!, u: elem.type, at: .location(node, .tuple) + .element(i)))
    }

    node.type = TypeVariable()
    var choices: [Constraint] = []

    if let ident = node.callee as? Ident {
      // If the callee's an identifier, it may be a tuple label rather than a function name, hence
      // requiring the addition of a conformance constraint with the type of the node.
      let tupleType = context.getTupleType(label: ident.name, elements: elements)
      choices.append(.conformance(t: tupleType, u: node.type!, at: .location(node, .tuple)))

      if ident.scope?.symbols[ident.name] == nil {
        // If there aren't any symbols for the identifier, it can't represent a function.
        context.add(constraint: choices[0])
        return
      }
    }

    // In cases the callee may represent a function, we need to build its supposed type as well.
    try visit(node.callee)
    let domain = context.getTupleType(label: nil, elements: elements)
    let funcType = context.getFunctionType(from: domain, to: node.type!)
    choices.append(.equality(t: node.callee.type!, u: funcType, at: .location(node, .call)))

    if choices.count == 1 {
      context.add(constraint: choices[0])
    } else {
      context.add(constraint: .disjunction(choices, at: .location(node, .call)))
    }
  }

  public func visit(_ node: Arg) throws {
    try visit(node.value)
    node.type = node.value.type
  }

  public func visit(_ node: Tuple) throws {
    for elem in node.elements {
      try visit(elem)
    }
    node.type = context.getTupleType(
      label: nil,
      elements: node.elements.map { TupleTypeElem(label: $0.label, type: $0.type!) })
  }

  public func visit(_ node: TupleElem) throws {
    try visit(node.value)
    node.type = node.value.type
  }

  public func visit(_ node: Ident) throws {
    // Retrieve the symbol(s) associated with the identifier.
    guard let symbols = node.scope?.symbols[node.name] else {
      context.add(error: SAError.undefinedSymbol(name: node.name), on: node)
      node.type = ErrorType.get
      return
    }

    // FIXME: Load overloads from parent scopes. To make sure we respect shadowing, we could stop
    // looking further down the stack as soon as we encounter a non-overloadable symbol, as this
    // property should have been properly set during the name binding pass.

    // Create a disjunction of constraint for each symbol, so as to let the solver explore the
    // different possible choices.
    node.type = TypeVariable()
    let choices: [Constraint] = symbols.map {
      .equality(t: node.type!, u: $0.type!, at: .location(node, .identifier))
    }
    if choices.count == 1 {
      context.add(constraint: choices[0])
    } else {
      context.add(constraint: .disjunction(choices, at: .location(node, .identifier)))
    }
  }

  public func visit(_ node: Scalar<Bool>) throws {
    node.type = BuiltinType.bool
  }

  public func visit(_ node: Scalar<Int>) throws {
    node.type = BuiltinType.int
  }

  public func visit(_ node: Scalar<Double>) throws {
    node.type = BuiltinType.float
  }

  public func visit(_ node: Scalar<String>) throws {
    node.type = BuiltinType.string
  }

  // MARK: Type signature handling

  private func read(signature: FuncSign) -> TypeBase {
    return context.getFunctionType(
      from: read(signature: signature.domain),
      to  : read(signature: signature.codomain))
  }

  private func read(signature: TupleSign) -> TupleType {
    return context.getTupleType(
      label: signature.label,
      elements: signature.elements.map({
        TupleTypeElem(label: $0.label, type: read(signature: $0.signature))
      }))
  }

  private func read(signature: UnionSign) -> UnionType {
    return context.getUnionType(cases: Set(signature.cases.map({ read(signature: $0) })))
  }

  private func read(signature: TypeIdent) -> TypeBase {
    guard let symbols = signature.scope?.symbols[signature.name] else {
      // The symbols of an identifier couldn't be linked; we use an error type.
      context.add(error: SAError.undefinedSymbol(name: signature.name), on: signature)
      return ErrorType.get
    }

    // Type identifiers should be associated with a unique metatype.
    guard symbols.count == 1, let meta = symbols[0].type as? Metatype else {
      context.add(error: SAError.invalidTypeIdentifier(name: signature.name), on: signature)
      return ErrorType.get
    }

    signature.type = meta
    return meta.type
  }

}
