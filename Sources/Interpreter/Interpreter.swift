import AST
import Parser
import Sema

public struct Interpreter {

  public init(debug: Bool = false) {
    self.debug = debug
    self.symbolCreator = SymbolCreator(context: context)
    self.nameBinder = NameBinder(context: context)
    self.constraintCreator = ConstraintCreator(context: context)
  }

  /// Whether or not the interpreter is in debug mode.
  public let debug: Bool
  /// The AST context of the interpreter.
  public let context = ASTContext()

  private let symbolCreator: SymbolCreator
  private let nameBinder: NameBinder
  private let constraintCreator: ConstraintCreator

  // Load a module from a text input.
  @discardableResult
  public mutating func loadModule(fromString input: String) throws -> Module {
    // Parse the module into an untyped AST.
    let parser = try Parser(source: input)
    var module = try parser.parseModule()

    // Run semantic analysis to get the typed AST.
    module = try runSema(on: module) as! Module
    context.modules.append(module)
    return module
  }

  // Interpret an expression from a text input, within the currently loaded context.
  public func interpret(string input: String) throws -> Any {
    // Parse the epxression into an untyped AST.
    let parser = try Parser(source: input)
    let untypedExpr = try parser.parseExpr()

    // Run semantic analysis to get the typed AST.
    let typedExpr = try runSema(on: untypedExpr) as! Expr
    return typedExpr
  }

  // Perform type inference on an untyped AST.
  private func runSema(on ast: Node) throws -> Node {
    try symbolCreator.visit(ast)
    try nameBinder.visit(ast)
    try constraintCreator.visit(ast)

    if debug {
      for constraint in context.typeConstraints {
        constraint.prettyPrint()
      }
      print()
    }

    var solver = ConstraintSolver(constraints: context.typeConstraints, in: context)
    let result = solver.solve()

    var typedAST = ast
    switch result {
    case .success(let solution):
      let dispatcher = Dispatcher(context: context, solution: solution)
      typedAST = try dispatcher.transform(ast)

    case .failure(let errors):
      for error in errors {
        context.add(
          error: SAError.unsolvableConstraint(constraint: error.constraint, cause: error.cause),
          on: error.constraint.location.resolved)
      }
    }

    guard context.errors.isEmpty
      else { throw InterpreterError.staticFailure(errors: context.errors) }
    return typedAST
  }

}
