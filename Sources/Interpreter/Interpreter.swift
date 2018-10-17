import AST
import Parser
import Sema

public struct Interpreter {

  public init(debug: Bool = false) {
    self.debug = debug
    self.symbolCreator = SymbolCreator(context: astContext)
    self.nameBinder = NameBinder(context: astContext)
    self.constraintCreator = ConstraintCreator(context: astContext)
  }

  /// Whether or not the interpreter is in debug mode.
  public let debug: Bool
  /// The AST context of the interpreter.
  public let astContext = ASTContext()

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
    astContext.modules.append(module)
    return module
  }

  // Evaluate an expression from a text input, within the currently loaded context.
  public func eval(string input: String) throws -> Value {
    // Parse the epxression into an untyped AST.
    let parser = try Parser(source: input)
    let untypedExpr = try parser.parseExpr()

    // Run semantic analysis to get the typed AST.
    let typedExpr = try runSema(on: untypedExpr) as! Expr
    return eval(expression: typedExpr)
  }

  public func eval(expression: Expr) -> Value {
    // Initialize the evaluation context with the top-level symbols of all loaded modules.
    var evalContext: [Symbol: Value] = [:]
    for module in astContext.modules {
      for (symbol, function) in module.functions {
        evalContext[symbol] = .function(function)
      }
    }

    // Evaluate the expression.
    return eval(expression, in: evalContext)
  }

  private func eval(_ expr: Expr, in evalContext: [Symbol: Value]) -> Value {
    switch expr {
    case let e as Call          : return eval(e, in: evalContext)
    case let e as Tuple         : return eval(e, in: evalContext)
    case let e as Ident         : return eval(e, in: evalContext)
    case let e as Scalar<Bool>  : return .bool(e.value)
    case let e as Scalar<Int>   : return .int(e.value)
    case let e as Scalar<Double>: return .real(e.value)
    case let e as Scalar<String>: return .string(e.value)
    default:
      fatalError()
    }
  }

  public func eval(_ expr: Call, in evalContext: [Symbol: Value]) -> Value {
    // Evaluate the callee.
    let callee = eval(expr.callee, in: evalContext)
    guard case .function(let function) = callee
      else { fatalError("invalid expression: callee is not a function") }

    // Evaluate the arguments.
    let arguments = expr.arguments.map { eval($0.value, in: evalContext) }

    // Update the evaluation context with the function's arguments.
    var funcContext = evalContext
    for (parameter, argument) in zip(function.signature.domain.elements, arguments) {
      if let label = parameter.label {
        let symbols = function.innerScope!.symbols[label]!
        assert(symbols.count == 1)
        funcContext[symbols[0]] = argument
      }
    }

    // Evaluate the function's body.
    return eval(function.body, in: funcContext)
  }

  public func eval(_ expr: Tuple, in evalContext: [Symbol: Value]) -> Value {
    // Evaluate the tuple's elements.
    let elements = expr.elements.map { (label: $0.label, value: eval($0.value, in: evalContext)) }
    return .tuple(label: expr.label, elements: elements)
  }

  public func eval(_ expr: Ident, in evalContext: [Symbol: Value]) -> Value {
    guard let sym = expr.symbol
      else { fatalError("invalid expression: missing symbol") }

    // Look for the identifier's symbol in the evaluation context.
    guard let value = evalContext[sym]
      else { fatalError("invalid expression: unbound identifier '\(expr.name)'") }
    return value
  }

  // Perform type inference on an untyped AST.
  private func runSema(on ast: Node) throws -> Node {
    try symbolCreator.visit(ast)
    try nameBinder.visit(ast)
    try constraintCreator.visit(ast)

    if debug {
      for constraint in astContext.typeConstraints {
        constraint.prettyPrint()
      }
      print()
    }

    var solver = ConstraintSolver(constraints: astContext.typeConstraints, in: astContext)
    let result = solver.solve()

    var typedAST = ast
    switch result {
    case .success(let solution):
      let dispatcher = Dispatcher(context: astContext, solution: solution)
      typedAST = try dispatcher.transform(ast)

    case .failure(let errors):
      for error in errors {
        astContext.add(
          error: SAError.unsolvableConstraint(constraint: error.constraint, cause: error.cause),
          on: error.constraint.location.resolved)
      }
    }

    guard astContext.errors.isEmpty
      else { throw InterpreterError.staticFailure(errors: astContext.errors) }
    return typedAST
  }

}
