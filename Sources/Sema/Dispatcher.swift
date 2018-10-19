import AST
import Utils

/// Transformer that applies a type solution to an untyped AST.
///
/// This pass is responsible to finalize the AST typing. It does so by:
/// * Reifying the type of each node, according to the solution it is provided with.
/// * Resolving the symbol associated with each identifier, based on their type.
///
/// - Note: This pass may fail if the dispatcher is unable to unambiguously disambiguise the
///   semantics of a particular node.
public final class Dispatcher: ASTTransformer {

  public init(context: ASTContext) {
    self.context = context
    self.solution = [:]
  }

  public init(context: ASTContext, solution: SubstitutionTable) {
    self.context = context
    self.solution = solution
  }

  /// The AST context.
  public let context: ASTContext
  /// The substitution map obtained after inference.
  public let solution: SubstitutionTable
  /// The tuple types already reified.
  private var visited: [TupleType] = []

  public func transform(_ node: Module) throws -> Node {
    // Reify the types of the symbols in the scope of the module.
    node.innerScope.map { reifyScopeSymbols(of: $0) }
    node.statements = try node.statements.map(transform)
    return node
  }

  public func transform(_ node: Func) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Reify the types of the symbols in the scope of the function.
    node.innerScope.map { reifyScopeSymbols(of: $0) }
    assert(node.type == node.symbol?.type)

    node.signature = try transform(node.signature) as! FuncSign
    node.body = try transform(node.body) as! Expr
    return node
  }

  public func transform(_ node: TypeIdent) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    return node
  }

  public func transform(_ node: FuncSign) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.domain = try transform(node.domain) as! TupleSign
    node.codomain = try transform(node.codomain) as! TypeSign
    return node
  }

  public func transform(_ node: TupleSign) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.elements = try node.elements.map(transform) as! [TupleSignElem]
    return node
  }

  public func transform(_ node: UnionSign) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.cases = try node.cases.map(transform) as! [TypeSign]
    return node
  }

  public func transform(_ node: If) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Reify the types of the symbols in the scope of each branch.
    node.thenScope.map { reifyScopeSymbols(of: $0) }
    node.elseScope.map { reifyScopeSymbols(of: $0) }

    node.condition = try transform(node.condition) as! Expr
    node.thenExpr = try transform(node.thenExpr) as! Expr
    node.elseExpr = try transform(node.elseExpr) as! Expr
    return node
  }

  public func transform(_ node: Match) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.subject = try transform(node.subject) as! Expr
    node.cases = try node.cases.map(transform) as! [MatchCase]
    return node
  }

  public func transform(_ node: MatchCase) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Reify the types of the symbols in the scope of the case.
    node.innerScope.map { reifyScopeSymbols(of: $0) }

    node.pattern = try transform(node.pattern) as! Expr
    node.value = try transform(node.value) as! Expr
    return node
  }

  public func transform(_ node: LetBinding) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    assert(node.type == node.symbol?.type)

    return node
  }

  public func transform(_ node: Binary) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.op = try transform(node.op) as! Ident
    node.left = try transform(node.left) as! Expr
    node.right = try transform(node.right) as! Expr
    return node
  }

  public func transform(_ node: Unary) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.op = try transform(node.op) as! Ident
    node.operand = try transform(node.operand) as! Expr
    return node
  }

  public func transform(_ node: Call) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.callee = try transform(node.callee) as! Expr
    node.arguments = try node.arguments.map(transform) as! [Arg]
    return node
  }

  public func transform(_ node: Arg) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.value = try transform(node.value) as! Expr
    return node
  }

  public func transform(_ node: Tuple) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.elements = try node.elements.map(transform) as! [TupleElem]
    return node
  }

  public func transform(_ node: TupleElem) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.value = try transform(node.value) as! Expr
    return node
  }

  public func transform(_ node: Select) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    node.owner = try transform(node.owner) as! Expr
    node.ownee = try transform(node.ownee) as! Ident
    return node
  }

  public func transform(_ node: Ident) throws -> Node {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Identify the symbol of the identifier.
    var scope = node.scope
    var choices: [Symbol] = []
    while scope != nil {
      choices.append(contentsOf: (scope!.symbols[node.name] ?? []))
      scope = scope?.parent
    }

    // In case there are multiple candidates, look for one that matches the node's type.
    choices = choices.filter { $0.type == node.type }
    assert(choices.count > 0)

    guard choices.count == 1 else {
      // If there are still mutiple candidates, the program is ambiguous.
      context.add(error: SAError.ambiguousCall(identifier: node, choices: choices), on: node)
      return node
    }

    let symbol = choices[0]
    node.symbol = symbol
    assert(node.type == node.symbol?.type)

    return node
  }

  private func reifyScopeSymbols(of scope: Scope) {
    for symbol in scope.symbols.values.joined() {
      symbol.type = symbol.type.map { solution.reify(type: $0, in: context, skipping: &visited) }
    }
  }

}
