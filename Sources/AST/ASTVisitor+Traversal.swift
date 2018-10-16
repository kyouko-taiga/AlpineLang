public extension ASTVisitor {

  // swiftlint:disable cyclomatic_complexity
  func visit(_ node: Node) throws {
    switch node {
    case let n as Module:          try visit(n)
    case let n as Func:            try visit(n)
    case let n as TypeAlias:       try visit(n)
    case let n as FuncSign:        try visit(n)
    case let n as TupleSign:       try visit(n)
    case let n as TupleSignElem:   try visit(n)
    case let n as UnionSign:       try visit(n)
    case let n as TypeIdent:       try visit(n)
    case let n as If:              try visit(n)
    case let n as Match:           try visit(n)
    case let n as MatchCase:       try visit(n)
    case let n as LetBinding:      try visit(n)
    case let n as Binary:          try visit(n)
    case let n as Unary:           try visit(n)
    case let n as Call:            try visit(n)
    case let n as Arg:             try visit(n)
    case let n as Tuple:           try visit(n)
    case let n as TupleElem:       try visit(n)
    case let n as Select:          try visit(n)
    case let n as Ident:           try visit(n)
    case let n as Scalar<Bool>:    try visit(n)
    case let n as Scalar<Int>:     try visit(n)
    case let n as Scalar<Double>:  try visit(n)
    case let n as Scalar<String>:  try visit(n)
    default:
      assertionFailure("unexpected node during generic visit")
    }
  }
  // swiftlint:enable cyclomatic_complexity

  func visit(_ nodes: [Node]) throws {
    for node in nodes {
      try visit(node)
    }
  }

  func visit(_ node: Module) throws {
    try traverse(node)
  }

  func traverse(_ node: Module) throws {
    try visit(node.statements)
  }

  // MARK: Declarations

  func visit(_ node: Func) throws {
    try traverse(node)
  }

  func traverse(_ node: Func) throws {
    try visit(node.signature)
    try visit(node.body)
  }

  func visit(_ node: TypeAlias) throws {
    try traverse(node)
  }

  func traverse(_ node: TypeAlias) throws {
    try visit(node.signature)
  }

  // MARK: Type signatures

  func visit(_ node: FuncSign) throws {
    try traverse(node)
  }

  func traverse(_ node: FuncSign) throws {
    try visit(node.domain)
    try visit(node.codomain)
  }

  func visit(_ node: TupleSign) throws {
    try traverse(node)
  }

  func traverse(_ node: TupleSign) throws {
    try visit(node.elements)
  }

  func visit(_ node: TupleSignElem) throws {
    try traverse(node)
  }

  func traverse(_ node: TupleSignElem) throws {
    try visit(node.signature)
  }

  func visit(_ node: UnionSign) throws {
    try traverse(node)
  }

  func traverse(_ node: UnionSign) throws {
    try visit(node.cases)
  }

  func visit(_ node: TypeIdent) {
  }

  // MARK: Expressions

  func visit(_ node: If) throws {
    try traverse(node)
  }

  func traverse(_ node: If) throws {
    try visit(node.condition)
    try visit(node.thenExpr)
    try visit(node.elseExpr)
  }

  func visit(_ node: Match) throws {
    try traverse(node)
  }

  func traverse(_ node: Match) throws {
    try visit(node.subject)
    try visit(node.cases)
  }

  func visit(_ node: MatchCase) throws {
    try traverse(node)
  }

  func traverse(_ node: MatchCase) throws {
    try visit(node.pattern)
    try visit(node.value)
  }

  func visit(_ node: LetBinding) throws {
  }

  func visit(_ node: Binary) throws {
    try traverse(node)
  }

  func traverse(_ node: Binary) throws {
    try visit(node.op)
    try visit(node.left)
    try visit(node.right)
  }

  func visit(_ node: Unary) throws {
    try traverse(node)
  }

  func traverse(_ node: Unary) throws {
    try visit(node.op)
    try visit(node.operand)
  }

  func visit(_ node: Call) throws {
    try traverse(node)
  }

  func traverse(_ node: Call) throws {
    try visit(node.callee)
    try visit(node.arguments)
  }

  func visit(_ node: Arg) throws {
    try traverse(node)
  }

  func traverse(_ node: Arg) throws {
    try visit(node.value)
  }

  func visit(_ node: Tuple) throws {
    try traverse(node)
  }

  func traverse(_ node: Tuple) throws {
    try visit(node.elements)
  }

  func visit(_ node: TupleElem) throws {
    try traverse(node)
  }

  func traverse(_ node: TupleElem) throws {
    try visit(node.value)
  }

  func visit(_ node: Select) throws {
    try traverse(node)
  }

  func traverse(_ node: Select) throws {
    try visit(node.owner)
    try visit(node.ownee)
  }

  func visit(_ node: Ident) {
  }

  func visit(_ node: Scalar<Bool>) {
  }

  func visit(_ node: Scalar<Int>) {
  }

  func visit(_ node: Scalar<Double>) {
  }

  func visit(_ node: Scalar<String>) {
  }

}
