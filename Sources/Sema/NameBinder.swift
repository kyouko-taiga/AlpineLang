import AST
import Utils

public final class NameBinder: ASTVisitor, SAPass {

  public init(context: ASTContext) {
    self.context = context
  }

  /// The AST context.
  public let context: ASTContext

  /// A stack of scope, used to bind symbols to their respective scope, lexically.
  private var scopes: Stack<Scope> = []

  public func visit(_ node: Module) throws {
    scopes.push(node.innerScope!)
    try visit(node.statements)
    scopes.pop()
  }

  public func visit(_ node: Func) throws {
    scopes.push(node.innerScope!)
    try traverse(node)
    scopes.pop()
  }

  public func visit(_ node: If) throws {
    try visit(node.condition)

    scopes.push(node.thenScope!)
    try visit(node.thenExpr)
    scopes.pop()

    scopes.push(node.elseScope!)
    try visit(node.elseExpr)
    scopes.pop()
  }

  public func visit(_ node: MatchCase) throws {
    scopes.push(node.innerScope!)
    try traverse(node)
    scopes.pop()
  }

  public func visit(_ node: Ident) throws {  
    // Find the scope that defines the visited identifier.
    guard let scope = findScope(declaring: node.name) else {
      context.add(error: SAError.undefinedSymbol(name: node.name), on: node)
      return
    }
    node.scope = scope
  }

  public func visit(_ node: TypeIdent) throws {
    // Find the scope that defines the visited identifier.
    guard let scope = findScope(declaring: node.name) else {
      context.add(error: SAError.undefinedSymbol(name: node.name), on: node)
      return
    }
    node.scope = scope
  }

  private func findScope(declaring name: String) -> Scope? {
    // Search in the scopes of current module first.
    if let index = scopes.index(where: { $0.symbols[name] != nil }) {
      return scopes[index]
    }

    // If the symbol can't be found in the current module, search in the loaded ones. Note that we
    // search in the reverse order the modules were loaded, meaning that a module may shadow the
    // symbols of another module, loaded earlier.
    for module in context.modules.reversed() {
      if module.innerScope?.symbols[name] != nil {
        return module.innerScope!
      }
    }

    // If the symbol can't be found in any of the loaded modules, search in the built-in scope.
    if context.builtinScope.symbols[name] != nil {
      return context.builtinScope
    }

    // The symbol does not exist in any of the reachable scopes.
    return nil
  }

}
