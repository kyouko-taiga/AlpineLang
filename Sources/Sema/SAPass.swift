import AST

/// Base protocol for all static analysis passes.
public protocol SAPass {

  init(context: ASTContext)

  func visit(_ node: Module) throws

  /// The AST context.
  var context: ASTContext { get }

}
