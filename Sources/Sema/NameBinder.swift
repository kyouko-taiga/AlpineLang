import AST
import Utils

public final class NameBinder: ASTVisitor, SAPass {

  public init(context: ASTContext) {
    self.context = context

    // Load the built-in types.
    builtinScope = Scope(name: "Alpine", parent: nil, module: nil)
    builtinScope.create(name: "Bool"  , type: BuiltinType.bool.metatype)
    builtinScope.create(name: "Int"   , type: BuiltinType.int.metatype)
    builtinScope.create(name: "Float" , type: BuiltinType.float.metatype)
    builtinScope.create(name: "String", type: BuiltinType.string.metatype)

    // Load the built-in converters.
    let f2i = unaryFuncType(operand: .float , codomain: .int)
    let s2i = unaryFuncType(operand: .string, codomain: .int)
    let i2f = unaryFuncType(operand: .int   , codomain: .float)
    let s2f = unaryFuncType(operand: .string, codomain: .float)
    let i2s = unaryFuncType(operand: .int   , codomain: .string)
    let f2s = unaryFuncType(operand: .float , codomain: .string)

    builtinScope.create(name: "int"   , type: f2i, overloadable: true)
    builtinScope.create(name: "int"   , type: s2i, overloadable: true)
    builtinScope.create(name: "float" , type: i2f, overloadable: true)
    builtinScope.create(name: "float" , type: s2f, overloadable: true)
    builtinScope.create(name: "string", type: i2s, overloadable: true)
    builtinScope.create(name: "string", type: f2s, overloadable: true)

    // Load the built-in operators.
    let b2b = unaryFuncType(operand: .bool, codomain: .bool)
    builtinScope.create(name: "not", type: b2b, overloadable: true)

    let bb2b = binaryFuncType(lhs: .bool, rhs: .bool, codomain: .bool)
    builtinScope.create(name: "and", type: bb2b, overloadable: true)
    builtinScope.create(name: "or" , type: bb2b, overloadable: true)
    builtinScope.create(name: "="  , type: bb2b, overloadable: true)
    builtinScope.create(name: "!=" , type: bb2b, overloadable: true)

    let ii2b = binaryFuncType(lhs: .int, rhs: .int, codomain: .bool)
    builtinScope.create(name: "<"  , type: ii2b, overloadable: true)
    builtinScope.create(name: "<=" , type: ii2b, overloadable: true)
    builtinScope.create(name: ">"  , type: ii2b, overloadable: true)
    builtinScope.create(name: ">=" , type: ii2b, overloadable: true)
    builtinScope.create(name: "="  , type: ii2b, overloadable: true)
    builtinScope.create(name: "!=" , type: ii2b, overloadable: true)

    let i2i = unaryFuncType(operand: .int, codomain: .int)
    builtinScope.create(name: "+"  , type: i2i , overloadable: true)
    builtinScope.create(name: "-"  , type: i2i , overloadable: true)

    let ii2i = binaryFuncType(lhs: .int, rhs: .int, codomain: .int)
    builtinScope.create(name: "+"  , type: ii2i, overloadable: true)
    builtinScope.create(name: "-"  , type: ii2i, overloadable: true)
    builtinScope.create(name: "*"  , type: ii2i, overloadable: true)
    builtinScope.create(name: "/"  , type: ii2i, overloadable: true)
    builtinScope.create(name: "%"  , type: ii2i, overloadable: true)

    let ff2b = binaryFuncType(lhs: .int, rhs: .int, codomain: .float)
    builtinScope.create(name: "<"  , type: ff2b, overloadable: true)
    builtinScope.create(name: "<=" , type: ff2b, overloadable: true)
    builtinScope.create(name: ">"  , type: ff2b, overloadable: true)
    builtinScope.create(name: ">=" , type: ff2b, overloadable: true)
    builtinScope.create(name: "="  , type: ff2b, overloadable: true)
    builtinScope.create(name: "!=" , type: ff2b, overloadable: true)

    let f2f = unaryFuncType(operand: .float, codomain: .float)
    builtinScope.create(name: "+"  , type: f2f , overloadable: true)
    builtinScope.create(name: "-"  , type: f2f , overloadable: true)

    let ff2f = binaryFuncType(lhs: .float, rhs: .float, codomain: .float)
    builtinScope.create(name: "+"  , type: ff2f, overloadable: true)
    builtinScope.create(name: "-"  , type: ff2f, overloadable: true)
    builtinScope.create(name: "*"  , type: ff2f, overloadable: true)
    builtinScope.create(name: "/"  , type: ff2f, overloadable: true)
    builtinScope.create(name: "%"  , type: ff2f, overloadable: true)

    let ss2b = binaryFuncType(lhs: .string, rhs: .string, codomain: .bool)
    builtinScope.create(name: "<"  , type: ss2b, overloadable: true)
    builtinScope.create(name: "<=" , type: ss2b, overloadable: true)
    builtinScope.create(name: ">"  , type: ss2b, overloadable: true)
    builtinScope.create(name: ">=" , type: ss2b, overloadable: true)
    builtinScope.create(name: "="  , type: ss2b, overloadable: true)
    builtinScope.create(name: "!=" , type: ss2b, overloadable: true)

    let ss2s = binaryFuncType(lhs: .string, rhs: .string, codomain: .string)
    builtinScope.create(name: "+"  , type: ss2s, overloadable: true)
  }

  /// The AST context.
  public let context: ASTContext

  /// A stack of scope, used to bind symbols to their respective scope, lexically.
  private var scopes: Stack<Scope> = []
  /// The built-in scope.
  private var builtinScope: Scope

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
    if builtinScope.symbols[name] != nil {
      return builtinScope
    }

    // The symbol does not exist in any of the reachable scopes.
    return nil
  }

  private func unaryFuncType(operand: BuiltinType, codomain: BuiltinType) -> FunctionType {
    let domain = context.getTupleType(
      label: nil,
      elements: [TupleTypeElem(label: nil, type: operand)])
    return context.getFunctionType(from: domain, to: codomain)
  }

  private func binaryFuncType(lhs: BuiltinType, rhs: BuiltinType, codomain: BuiltinType)
    -> FunctionType
  {
    let domain = context.getTupleType(
      label: nil,
      elements: [
        TupleTypeElem(label: nil, type: lhs),
        TupleTypeElem(label: nil, type: rhs),
      ])
    return context.getFunctionType(from: domain, to: codomain)
  }

}
