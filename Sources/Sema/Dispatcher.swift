import AST
import Utils

/// Visitor that applies a type solution to an untyped AST.
///
/// This pass is responsible to finalize the AST typing. It does so by:
/// * Reifying the type of each node, according to the solution it is provided with.
/// * Resolving the symbol associated with each identifier, based on their type.
/// * Disambiguise named tuple and call expressions.
///
/// - Note: This pass may fail if the dispatcher is unable to unambiguously disambiguise the
///   semantics of a particular node.
public final class Dispatcher: ASTVisitor, SAPass {

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

  public func visit(_ node: Module) throws {
    // Reify the types of the symbols in the scope of the module.
    node.innerScope.map { reifyScopeSymbols(of: $0) }
    try traverse(node)
  }

  public func visit(_ node: Func) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Reify the types of the symbols in the scope of the function.
    node.innerScope.map { reifyScopeSymbols(of: $0) }

    try traverse(node)
    assert(node.type == node.symbol?.type)
  }

  public func visit(_ node: TypeIdent) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
  }

  public func visit(_ node: FuncSign) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Reify the type of the domain and codomain declarations.
    try visit(node.domain)
    try visit(node.codomain)
  }

  public func visit(_ node: TupleSign) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Reify the type of the tuple elements.
    try visit(node.elements)
  }

  public func visit(_ node: UnionSign) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Reify the type of the union's cases.
    try visit(node.cases)
  }

  public func visit(_ node: If) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Reify the types of the symbols in the scope of each branch.
    node.thenScope.map { reifyScopeSymbols(of: $0) }
    node.elseScope.map { reifyScopeSymbols(of: $0) }

    // Continue dispatching on the condition and branches.
    try traverse(node)
  }

  public func visit(_ node: Match) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Continue dispatching on the subject and cases.
    try traverse(node)
  }

  public func visit(_ node: MatchCase) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }

    // Reify the types of the symbols in the scope of the case.
    node.innerScope.map { reifyScopeSymbols(of: $0) }

    // Continue dispatching on the pattern and value.
    try traverse(node)
  }

  public func visit(_ node: LetBinding) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    assert(node.type == node.symbol?.type)
  }

  public func visit(_ node: Binary) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)
  }

  public func visit(_ node: Unary) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)
  }

  public func visit(_ node: Call) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)

    // TODO: Disambiguise named tuple expressions.
  }

  public func visit(_ node: Arg) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)
  }

  public func visit(_ node: Tuple) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)
  }

  public func visit(_ node: TupleElem) throws {
    // Reify the type of the node.
    node.type = node.type.map {
      solution.reify(type: $0, in: context, skipping: &visited)
    }
    try traverse(node)
  }

  public func visit(_ node: Ident) throws {
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
    assert(choices.count > 0)

    // TODO: Disambiguise when there are several choices.
    let symbol = choices[0]
    node.symbol = symbol
    assert(node.type == node.symbol?.type)
  }

  private func reifyScopeSymbols(of scope: Scope) {
    for symbol in scope.symbols.values.joined() {
      symbol.type = symbol.type.map { solution.reify(type: $0, in: context, skipping: &visited) }
    }
  }

}
