import AST
import Parser
import Sema

public struct Interpreter {

  public init(debug: Bool = false) {
    self.debug = debug
    self.normalizer = Normalizer()
    self.symbolCreator = SymbolCreator(context: astContext)
    self.nameBinder = NameBinder(context: astContext)
    self.constraintCreator = ConstraintCreator(context: astContext)
  }

  /// Whether or not the interpreter is in debug mode.
  public let debug: Bool
  /// The AST context of the interpreter.
  public let astContext = ASTContext()

  private let normalizer: Normalizer
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
  
  public func saveContext() -> ([FunctionType], [TupleType]) {
    return astContext.saveContext()
  }
  
  public func reloadContext(context: ([FunctionType], [TupleType])) {
    astContext.reloadContext(context: context)
  }

  // Evaluate an expression from a text input, within the currently loaded context.
  public func eval(string input: String) throws -> Value {
    
    // Parse the epxression into an untyped AST.
    let parser = try Parser(source: input)
    let expr = try parser.parseExpr()
    
    // Expressions can't be analyzed nor ran out-of-context, they must be nested in a module.
    let module = Module(statements: [expr], range: expr.range)
    
    // Run semantic analysis to get the typed AST.
    let typedModule = try runSema(on: module) as! Module

    // Compute the evaluation
    let res = eval(expression: typedModule.statements[0] as! Expr)
    
    return res
  }

  public func eval(expression: Expr) -> Value {
    // Initialize an evaluation context with top-level symbols from built-in and loaded modules.
    let evalContext: EvaluationContext = [:]
    for (symbol, function) in astContext.builtinScope.semantics {
      evalContext[symbol] = .builtinFunction(function)
    }

    for module in astContext.modules {
      for (symbol, function) in module.functions {
        evalContext[symbol] = .function(function, closure: [:])
      }
    }

    // Evaluate the expression.
    return eval(expression, in: evalContext)
  }

  private func eval(_ expr: Expr, in evalContext: EvaluationContext) -> Value {
    switch expr {
    case let e as Func          : return eval(e, in: evalContext)
    case let e as If            : return eval(e, in: evalContext)
    case let e as Match         : return eval(e, in: evalContext)
    case let e as Call          : return eval(e, in: evalContext)
    case let e as Tuple         : return eval(e, in: evalContext)
    case let e as Select        : return eval(e, in: evalContext)
    case let e as Ident         : return eval(e, in: evalContext)
    case let e as Scalar<Bool>  : return .bool(e.value)
    case let e as Scalar<Int>   : return .int(e.value)
    case let e as Scalar<Double>: return .real(e.value)
    case let e as Scalar<String>: return .string(e.value)
    default:
      fatalError()
    }
  }

  public func eval(_ expr: Func, in evalContext: EvaluationContext) -> Value {
    let closure = evalContext.copy
    let value = Value.function(expr, closure: closure)
    closure[expr.symbol!] = value
    return value
  }

  public func eval(_ expr: If, in evalContext: EvaluationContext) -> Value {
    // Evaluate the condition.
    let condition = eval(expr.condition, in: evalContext)
    guard case .bool(let value) = condition
      else { fatalError("non-boolean condition") }

    // Evaluate the branch, depending on the condition.
    return value
      ? eval(expr.thenExpr, in: evalContext)
      : eval(expr.elseExpr, in: evalContext)
  }

  public func eval(_ expr: Match, in evalContext: EvaluationContext) -> Value {
    // Evaluate the subject of the match.
    let subject = eval(expr.subject, in: evalContext)

    // Find the first pattern that matches the subject, along with its optional bindings.
    for matchCase in expr.cases {
      if let matchContext = match(subject, with: matchCase.pattern, in: evalContext) {
        return eval(matchCase.value, in: matchContext)
      }
    }

    // TODO: Sanitizing should make sure there's always at least one matching case for any subject,
    // or reject the program otherwise.
    fatalError("no matching pattern")
  }

  func match(_ subject: Value, with pattern: Expr, in evalContext: EvaluationContext)
    -> EvaluationContext?
  {
    switch pattern {
    case let binding as LetBinding:
      // TODO: Handle non-linear patterns.

      // Matching a value with a new binding obvioulsy succeed.
      let matchContext = evalContext.copy
      matchContext[binding.symbol!] = subject
      return matchContext

    case let tuplePattern as Tuple:
      guard case .tuple(let label, let elements) = subject
        else { return nil }
      guard (label == tuplePattern.label) && (elements.count == tuplePattern.elements.count)
        else { return nil }

      // Try merging each tuple element.
      var matchContext = evalContext.copy
      for (lhs, rhs) in zip(elements, tuplePattern.elements) {
        guard lhs.label == rhs.label
          else { return nil }
        guard let subMatchContext = match(lhs.value, with: rhs.value, in: matchContext)
          else { return nil }
        matchContext = subMatchContext
      }

      return matchContext

    default:
      // If the pattern is any expression other than a let binding or a tuple, we evaluate it and
      // use value equality to determine the result of the match.
      let value = eval(pattern, in: evalContext)

      // TODO: Semantic analysis should make sure there's an equality function between the subject
      // and the pattern, or reject the program otherwise. The current implementation reject all
      // values except native ones.
      switch (subject, value) {
      case (.bool(let lhs)  , .bool(let rhs))   : return lhs == rhs ? evalContext : nil
      case (.int(let lhs)   , .int(let rhs))    : return lhs == rhs ? evalContext : nil
      case (.real(let lhs)  , .real(let rhs))   : return lhs == rhs ? evalContext : nil
      case (.string(let lhs), .string(let rhs)) : return lhs == rhs ? evalContext : nil
      default:
        return nil
      }
    }
  }

  public func eval(_ expr: Call, in evalContext: EvaluationContext) -> Value {
    // Evaluate the callee and its arguments.
    let callee = eval(expr.callee, in: evalContext)
    let arguments = expr.arguments.map { eval($0.value, in: evalContext) }

    switch callee {
    case .builtinFunction(let function):
      let swiftArguments = arguments.compactMap { $0.swiftValue }
      assert(swiftArguments.count == arguments.count)
      return Value(value: function(swiftArguments))!

    case .function(let function, let closure):
      // Update the evaluation context with the function's arguments.
      let funcContext = evalContext.merging(closure) { _, rhs in rhs }
      for (parameter, argument) in zip(function.signature.domain.elements, arguments) {
        if let name = parameter.name {
          let symbols = function.innerScope!.symbols[name]!
          assert(symbols.count == 1)
          funcContext[symbols[0]] = argument
        }
      }

      // Evaluate the function's body.
      return eval(function.body, in: funcContext)

    default:
      fatalError("invalid expression: callee is not a function")
    }
  }

  public func eval(_ expr: Tuple, in evalContext: EvaluationContext) -> Value {
    // Evaluate the tuple's elements.
    let elements = expr.elements.map { (label: $0.label, value: eval($0.value, in: evalContext)) }
    return .tuple(label: expr.label, elements: elements)
  }

  public func eval(_ expr: Select, in evalContext: EvaluationContext) -> Value {
    // Evaluate the owner.
    let owner = eval(expr.owner, in: evalContext)
    guard case .tuple(label: _, let elements) = owner
      else { fatalError("invalid expression: expected owner to be a tuple") }

    switch expr.ownee {
    case .label(let label):
      guard let element = elements.first(where: { $0.label == label })
        else { fatalError("\(owner) has no member named \(label)") }
      return element.value

    case .index(let index):
      guard index < elements.count
        else { fatalError("\(owner) has no \(index)-th member") }
      return elements[index].value
    }
  }

  public func eval(_ expr: Ident, in evalContext: EvaluationContext) -> Value {
    guard let sym = expr.symbol
      else { fatalError("invalid expression: missing symbol") }

    // Look for the identifier's symbol in the evaluation context.
    guard let value = evalContext[sym]
      else { fatalError("invalid expression: unbound identifier '\(expr.name)'") }
    return value
  }

  // Perform type inference on an untyped AST.
  private func runSema(on module: Module) throws -> Node {
    var ast = try normalizer.transform(module)

    try symbolCreator.visit(module)
    try nameBinder.visit(module)
    try constraintCreator.visit(module)

    if debug {
      for constraint in astContext.typeConstraints {
        constraint.prettyPrint()
      }
      print()
    }

    var solver = ConstraintSolver(constraints: astContext.typeConstraints, in: astContext)
    let result = solver.solve()

    switch result {
    case .success(let solution):
      let dispatcher = Dispatcher(context: astContext, solution: solution)
      ast = try dispatcher.transform(module) as! Module

    case .failure(let errors):
      for error in errors {
        astContext.add(
          error: SAError.unsolvableConstraint(constraint: error.constraint, cause: error.cause),
          on: error.constraint.location.resolved)
      }
    }

    guard astContext.errors.isEmpty
      else { throw InterpreterError.staticFailure(errors: astContext.errors) }
    astContext.typeConstraints.removeAll()
    return ast
  }

}
