public extension ASTTransformer {

  // swiftlint:disable cyclomatic_complexity
  func transform(_ node: Node) throws -> Node {
    switch node {
    case let n as Module:          return try transform(n)
    case let n as Func:            return try transform(n)
    case let n as TypeAlias:       return try transform(n)
    case let n as FuncSign:        return try transform(n)
    case let n as TupleSign:       return try transform(n)
    case let n as TupleSignElem:   return try transform(n)
    case let n as UnionSign:       return try transform(n)
    case let n as TypeIdent:       return try transform(n)
    case let n as If:              return try transform(n)
    case let n as Match:           return try transform(n)
    case let n as MatchCase:       return try transform(n)
    case let n as LetBinding:      return try transform(n)
    case let n as Binary:          return try transform(n)
    case let n as Unary:           return try transform(n)
    case let n as Call:            return try transform(n)
    case let n as Arg:             return try transform(n)
    case let n as Tuple:           return try transform(n)
    case let n as TupleElem:       return try transform(n)
    case let n as Select:          return try transform(n)
    case let n as Ident:           return try transform(n)
    case let n as Scalar<Bool>:    return try transform(n)
    case let n as Scalar<Int>:     return try transform(n)
    case let n as Scalar<Double>:  return try transform(n)
    case let n as Scalar<String>:  return try transform(n)
    default:
      fatalError("unexpected node during generic transform")
    }
  }
  // swiftlint:enable cyclomatic_complexity

  func transform(_ node: Module) throws -> Node {
    node.statements = try node.statements.map(transform)
    return node
  }

  // MARK: Declarations

  func transform(_ node: Func) throws -> Node {
    node.signature = try transform(node.signature) as! FuncSign
    node.body = try transform(node.body) as! Expr
    return node
  }

  func transform(_ node: TypeAlias) throws -> Node {
    node.signature = try transform(node.signature) as! TypeSign
    return node
  }

  // MARK: Type signatures

  func transform(_ node: FuncSign) throws -> Node {
    node.domain = try transform(node.domain) as! TupleSign
    node.codomain = try transform(node.codomain) as! TypeSign
    return node
  }

  func transform(_ node: TupleSign) throws -> Node {
    node.elements = try node.elements.map(transform) as! [TupleSignElem]
    return node
  }

  func transform(_ node: TupleSignElem) throws -> Node {
    node.signature = try transform(node.signature) as! TypeSign
    return node
  }

  func transform(_ node: UnionSign) throws -> Node {
    node.cases = try node.cases.map(transform) as! [TypeSign]
    return node
  }

  func transform(_ node: TypeIdent) throws -> Node {
    return node
  }

  // MARK: Expressions

  func transform(_ node: If) throws -> Node {
    node.condition = try transform(node.condition) as! Expr
    node.thenExpr = try transform(node.thenExpr) as! Expr
    node.elseExpr = try transform(node.elseExpr) as! Expr
    return node
  }

  func transform(_ node: Match) throws -> Node {
    node.subject = try transform(node.subject) as! Expr
    node.cases = try node.cases.map(transform) as! [MatchCase]
    return node
  }

  func transform(_ node: MatchCase) throws -> Node {
    node.pattern = try transform(node.pattern) as! Expr
    node.value = try transform(node.value) as! Expr
    return node
  }

  func transform(_ node: LetBinding) throws -> Node {
    return node
  }

  func transform(_ node: Binary) throws -> Node {
    node.op = try transform(node.op) as! Ident
    node.left = try transform(node.left) as! Expr
    node.right = try transform(node.right) as! Expr
    return node
  }

  func transform(_ node: Unary) throws -> Node {
    node.op = try transform(node.op) as! Ident
    node.operand = try transform(node.operand) as! Expr
    return node
  }

  func transform(_ node: Call) throws -> Node {
    node.callee = try transform(node.callee) as! Expr
    node.arguments = try node.arguments.map(transform) as! [Arg]
    return node
  }

  func transform(_ node: Arg) throws -> Node {
    node.value = try transform(node.value) as! Expr
    return node
  }

  func transform(_ node: Tuple) throws -> Node {
    node.elements = try node.elements.map(transform) as! [TupleElem]
    return node
  }

  func transform(_ node: TupleElem) throws -> Node {
    node.value = try transform(node.value) as! Expr
    return node
  }

  func transform(_ node: Select) throws -> Node {
    node.owner = try transform(node.owner) as! Expr
    return node
  }

  func transform(_ node: Ident) -> Node {
    return node
  }

  func transform(_ node: Scalar<Bool>) -> Node {
    return node
  }

  func transform(_ node: Scalar<Int>) -> Node {
    return node
  }

  func transform(_ node: Scalar<Double>) -> Node {
    return node
  }

  func transform(_ node: Scalar<String>) -> Node {
    return node
  }

}
