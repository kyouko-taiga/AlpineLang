import AST
import Utils

/// A visitor that creates the scope and symbols of to be associated with the AST nodes.
///
/// This pass is responsible for three things:
/// * It annotates nodes delimiting scopes with the corresponding scope object.
/// * It annotates named declaration with scoped symbols that uniquely represent them.
/// * It creates the type corresponding to function declarations.
///
/// This pass must be ran before name binding can take place.
public final class SymbolCreator: ASTVisitor, SAPass {

  public init(context: ASTContext) {
    self.context = context
  }

  /// The AST context.
  public let context: ASTContext
  /// A stack of scopes used to determine in which one a new symbol should be created.
  private var scopes: Stack<Scope> = []

  /// The error symbol.
  private var errorSymbol: Symbol?

  public func visit(_ node: Module) throws {
    // Create a new scope for the module.
    node.innerScope = Scope(name: node.id, module: node)

    // Create the module's error symbol.
    errorSymbol = node.innerScope?.create(name: "<error>", type: ErrorType.get)

    // Visit the module's statements.
    scopes.push(node.innerScope!)
    try visit(node.statements)
    scopes.pop()
  }

  public func visit(_ node: Func) throws {
    let scope = scopes.top
    assert(scope != nil, "unscoped declaration")

    if let name = node.name {
      // Make sure the function's name can be declared in the current scope.
      let symbols = scope!.symbols[name]
      guard symbols?.all(satisfy: { $0.overloadable }) ?? true else {
        node.symbol = errorSymbol
        context.add(error: SAError.invalidRedeclaration(name: name), on: node)
        return
      }
    }

    // Create the inner scope of the function.
    let innerScope = Scope(name: node.name, parent: scope)
    node.innerScope = innerScope

    // Visit the function's domain to create symbols for its parameters.
    scopes.push(innerScope)
    var parameters: [TupleTypeElem] = []
    for element in node.signature.domain.elements {
      let param = TupleTypeElem(label: element.label, type: TypeVariable())
      parameters.append(param)

      if let label = element.label {
        innerScope.create(name: label, type: param.type)
      }
      try visit(element.signature)
    }

    let domain = context.getTupleType(label: nil, elements: parameters)
    let funcType = context.getFunctionType(from: domain, to: TypeVariable())
    node.symbol = scope!.create(name: node.name ?? "λ", type: funcType, overloadable: true)

    // Visit the function's body.
    try visit(node.body)
    scopes.pop()
  }

  public func visit(_ node: TypeAlias) throws {
    let scope = scopes.top
    assert(scope != nil, "unscoped declaration")

    // Make sure the type alias can be declared in the current scope.
    let symbols = scope!.symbols[node.name]
    guard symbols == nil else {
      node.symbol = errorSymbol
      context.add(error: SAError.duplicateDeclaration(name: node.name), on: node)
      return
    }

    node.symbol = scope!.create(name: node.name, type: TypeVariable().metatype)

    // Visit the alias' signature.
    try visit(node.signature)
  }

  public func visit(_ node: If) throws {
    // Visit the condition.
    try visit(node.condition)

    // Create the scope delimited by the then branch before visiting it.
    node.thenScope = Scope(parent: scopes.top)
    scopes.push(node.thenScope!)
    try visit(node.thenExpr)
    scopes.pop()

    // Create the scope delimited by the selse branch before visiting it.
    node.elseScope = Scope(parent: scopes.top)
    scopes.push(node.elseScope!)
    try visit(node.elseExpr)
    scopes.pop()
  }

  public func visit(_ node: MatchCase) throws {
    // Create the scope delimited by the case.
    node.innerScope = Scope(parent: scopes.top)

    // Visit the match pattern and value. Note that both are in the same scope!
    scopes.push(node.innerScope!)
    try visit(node.pattern)
    try visit(node.value)
    scopes.pop()
  }

  public func visit(_ node: LetBinding) throws {
    let scope = scopes.top
    assert(scope != nil, "unscoped declaration")

    // Make sure the binding can be declared in the current scope.
    let symbols = scope!.symbols[node.name]
    guard symbols == nil else {
      node.symbol = errorSymbol
      context.add(error: SAError.duplicateDeclaration(name: node.name), on: node)
      return
    }

    node.symbol = scope!.create(name: node.name, type: TypeVariable())
    node.type = node.symbol?.type

    // NOTE: The current way of creating symbols for let bindings makes it impossible to create
    // non-linear patterns, as one can't write `match tuple with (let x, let x)`. We'll probably
    // need to alter the syntax to handle non-linear patterns, or borrow from Swift's use of
    // where clauses.
  }

}
