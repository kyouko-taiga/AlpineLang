import Utils

precedencegroup StreamPrecedence {
  associativity: left
  lowerThan: TernaryPrecedence
}

infix operator <<<: StreamPrecedence

public final class ASTDumper<OutputStream>: ASTVisitor where OutputStream: TextOutputStream {

  public init(outputTo outputStream: OutputStream) {
    self.outputStream = outputStream
  }

  public var outputStream: OutputStream

  private var level: Int = 0
  private var indent: String {
    return String(repeating: "  ", count: level)
  }

  public func dump(ast: Node) {
    try! visit(ast)
    print()
  }

  public func visit(_ node: Module) throws {
    self <<< indent <<< "(module"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"

    if !node.statements.isEmpty {
      self <<< "\n"
      withIndentation { try visit(node.statements) }
    }
    self <<< ")"
  }

  public func visit(_ node: Func) throws {
    self <<< indent <<< "(func"
    if let name = node.name {
      self <<< " '\(name)'"
    }
    self <<< " type='" <<< node.type <<< "'"
    self <<< " symbol='" <<< node.symbol?.name <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(signature\n"
      withIndentation { try visit(node.signature) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(body\n"
      withIndentation { try visit(node.body) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: TypeAlias) throws {
    self <<< indent <<< "(type_alias '\(node.name)'"
    self <<< " symbol='" <<< node.symbol?.name <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(signature\n"
      withIndentation { try visit(node.signature) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: FuncSign) throws {
    self <<< indent <<< "(func_sign"
    withIndentation {
      self <<< "\n" <<< indent <<< "(domain\n"
      withIndentation { try visit(node.domain) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(codomain\n"
      withIndentation { try visit(node.codomain) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: TupleSign) throws {
    self <<< indent <<< "(tuple_sign"
    if let label = node.label {
      self <<< " '\(label)'"
    }
    if !node.elements.isEmpty {
      self <<< "\n"
      withIndentation { try visit(node.elements) }
    }
    self <<< ")"
  }

  public func visit(_ node: TupleSignElem) throws {
    self <<< indent <<< "(tuple_sign_elem"
    self <<< " '" <<< node.label <<< "'"
    self <<< " '" <<< node.name <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(signature\n"
      withIndentation { try visit(node.signature) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: UnionSign) throws {
    self <<< indent <<< "(union_sign"
    if !node.cases.isEmpty {
      self <<< "\n"
      withIndentation { try visit(node.cases) }
    }
    self <<< ")"
  }

  public func visit(_ node: TypeIdent) throws {
    self <<< indent <<< "(type_ident '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< ")"
  }

  public func visit(_ node: If) throws {
    self <<< indent <<< "(if"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(condition\n"
      withIndentation { try visit(node.condition) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(then"
      self <<< " inner_scope='" <<< node.thenScope <<< "'\n"
      withIndentation { try visit(node.thenExpr) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(else"
      self <<< " inner_scope='" <<< node.elseScope <<< "'\n"
      withIndentation { try visit(node.elseExpr) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: Match) throws {
    self <<< indent <<< "(match"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(subject\n"
      withIndentation { try visit(node.subject) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(cases\n"
      withIndentation { try visit(node.cases) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: MatchCase) throws {
    self <<< indent <<< "(match_case"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " inner_scope='" <<< node.innerScope <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(pattern\n"
      withIndentation { try visit(node.pattern) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(value\n"
      withIndentation { try visit(node.value) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: LetBinding) throws {
    self <<< indent <<< "(let_binding '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< ")"
  }

  public func visit(_ node: Binary) throws {
    self <<< indent <<< "(binary"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(left\n"
      withIndentation { try visit(node.left) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(infix_operator\n"
      withIndentation { visit(node.op) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(right\n"
      withIndentation { try visit(node.right) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: Unary) throws {
    self <<< indent <<< "(unary"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(prefix_operator\n"
      withIndentation { visit(node.op) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(operand\n"
      withIndentation { try visit(node.operand) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: Call) throws {
    self <<< indent <<< "(call"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(callee\n"
      withIndentation { try visit(node.callee) }
      self <<< ")"
      if !node.arguments.isEmpty {
        self <<< "\n" <<< indent <<< "(arguments\n"
        withIndentation { try visit(node.arguments) }
        self <<< ")"
      }
    }
    self <<< ")"
  }

  public func visit(_ node: Arg) {
    self <<< indent <<< "(arg"
    self <<< " '" <<< node.label <<< "'"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n"
      try visit(node.value)
    }
    self <<< ")"
  }

  public func visit(_ node: Tuple) throws {
    self <<< indent <<< "(tuple"
    self <<< " type='" <<< node.type <<< "'"
    if let label = node.label {
      self <<< " '\(label)'"
    }
    if !node.elements.isEmpty {
      self <<< "\n"
      withIndentation { try visit(node.elements) }
    }
    self <<< ")"
  }

  public func visit(_ node: TupleElem) throws {
    self <<< indent <<< "(tuple_elem"
    self <<< " '" <<< node.label <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(value\n"
      withIndentation { try visit(node.value) }
      self <<< ")"
    }
    self <<< ")"
  }

  public func visit(_ node: Select) {
    self <<< indent <<< "(select"
    self <<< " type='" <<< node.type <<< "'"
    withIndentation {
      self <<< "\n" <<< indent <<< "(owner\n"
      withIndentation { try visit(node.owner) }
      self <<< ")"
      self <<< "\n" <<< indent <<< "(ownee '\(node.ownee)')"
    }
    self <<< ")"
  }

  public func visit(_ node: Ident) {
    self <<< indent <<< "(ident '\(node.name)'"
    self <<< " type='" <<< node.type <<< "'"
    self <<< " scope='" <<< node.scope <<< "'"
    self <<< ")"
  }

  public func visit(_ node: Scalar<Bool>) {
    self <<< indent <<< "(scalar \(node.value)"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: Scalar<Int>) {
    self <<< indent <<< "(scalar \(node.value)"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: Scalar<Double>) {
    self <<< indent <<< "(scalar \(node.value)"
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ node: Scalar<String>) {
    self <<< indent <<< "(scalar \"\(node.value)\""
    self <<< " type='" <<< node.type <<< "'"
    self <<< ")"
  }

  public func visit(_ nodes: [Node]) throws {
    for node in nodes {
      try visit(node)
      if node != nodes.last {
        self <<< "\n"
      }
    }
  }

  fileprivate func withIndentation(body: () throws -> Void) {
    level += 1
    try! body()
    level -= 1
  }

  @discardableResult
  fileprivate static func <<< <T>(dumper: ASTDumper, item: T) -> ASTDumper {
    dumper.outputStream.write(String(describing: item))
    return dumper
  }

  @discardableResult
  fileprivate static func <<< <T>(dumper: ASTDumper, item: T?) -> ASTDumper {
    dumper.outputStream.write(item.map({ String(describing: $0) }) ?? "_")
    return dumper
  }

}
