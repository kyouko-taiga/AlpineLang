public class BuiltinScope: Scope {

  internal init(context: ASTContext) {
    self.context = context
    super.init(name: "Alpine", parent: nil, module: nil)

    // Built-in types.
    create(name: "Bool"  , type: BuiltinType.bool.metatype)
    create(name: "Int"   , type: BuiltinType.int.metatype)
    create(name: "Float" , type: BuiltinType.float.metatype)
    create(name: "String", type: BuiltinType.string.metatype)

    var sym: Symbol

    let f2i = unaryFuncType(operand: .float , codomain: .int)
    let s2i = unaryFuncType(operand: .string, codomain: .int)
    let i2f = unaryFuncType(operand: .int   , codomain: .float)
    let s2f = unaryFuncType(operand: .string, codomain: .float)
    let i2s = unaryFuncType(operand: .int   , codomain: .string)
    let f2s = unaryFuncType(operand: .float , codomain: .string)
    let b2b = unaryFuncType(operand: .bool  , codomain: .bool)
    let i2i = unaryFuncType(operand: .int   , codomain: .int)
    let f2f = unaryFuncType(operand: .float , codomain: .float)
    let bb2b = binaryFuncType(lhs: .bool  , rhs: .bool  , codomain: .bool)
    let ii2b = binaryFuncType(lhs: .int   , rhs: .int   , codomain: .bool)
    let ii2i = binaryFuncType(lhs: .int   , rhs: .int   , codomain: .int)
    let ff2b = binaryFuncType(lhs: .int   , rhs: .int   , codomain: .float)
    let ff2f = binaryFuncType(lhs: .float , rhs: .float , codomain: .float)
    let ss2b = binaryFuncType(lhs: .string, rhs: .string, codomain: .bool)
    let ss2s = binaryFuncType(lhs: .string, rhs: .string, codomain: .string)

    // Built-in converters.

    sym = create(name: "int", type: f2i, overloadable: true)
    semantics[sym] = { (args: [Any]) in Int(args[0] as! Double) }

    sym = create(name: "int", type: s2i, overloadable: true)
    semantics[sym] = { (args: [Any]) in Int(args[0] as! String)! }

    sym = create(name: "float", type: i2f, overloadable: true)
    semantics[sym] = { (args: [Any]) in Double(args[0] as! Int) }

    sym = create(name: "float", type: s2f, overloadable: true)
    semantics[sym] = { (args: [Any]) in Double(args[0] as! String)! }

    sym = create(name: "string", type: i2s, overloadable: true)
    semantics[sym] = { (args: [Any]) in String(args[0] as! Int) }

    sym = create(name: "string", type: f2s, overloadable: true)
    semantics[sym] = { (args: [Any]) in String(args[0] as! Double) }

    // Built-in operators.

    sym = create(name: "not", type: b2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in !(args[0] as! Bool) }

    sym = create(name: "and", type: bb2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Bool) && (args[1] as! Bool) }

    sym = create(name: "or" , type: bb2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Bool) || (args[1] as! Bool) }

    sym = create(name: "="  , type: bb2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Bool) == (args[1] as! Bool) }

    sym = create(name: "!=" , type: bb2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Bool) != (args[1] as! Bool) }

    sym = create(name: "<"  , type: ii2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) < (args[1] as! Int) }

    sym = create(name: "<=" , type: ii2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) <= (args[1] as! Int) }

    sym = create(name: ">"  , type: ii2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) > (args[1] as! Int) }

    sym = create(name: ">=" , type: ii2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) >= (args[1] as! Int) }

    sym = create(name: "="  , type: ii2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) == (args[1] as! Int) }

    sym = create(name: "!=" , type: ii2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) != (args[1] as! Int) }

    sym = create(name: "+"  , type: i2i , overloadable: true)
    semantics[sym] = { (args: [Any]) in +(args[0] as! Int) }

    sym = create(name: "-"  , type: i2i , overloadable: true)
    semantics[sym] = { (args: [Any]) in -(args[0] as! Int) }

    sym = create(name: "+"  , type: ii2i, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) + (args[1] as! Int) }

    sym = create(name: "-"  , type: ii2i, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) - (args[1] as! Int) }

    sym = create(name: "*"  , type: ii2i, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) * (args[1] as! Int) }

    sym = create(name: "/"  , type: ii2i, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) / (args[1] as! Int) }

    sym = create(name: "%"  , type: ii2i, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Int) % (args[1] as! Int) }

    sym = create(name: "<"  , type: ff2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Float) < (args[1] as! Float) }

    sym = create(name: "<=" , type: ff2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Float) <= (args[1] as! Float) }

    sym = create(name: ">"  , type: ff2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Float) > (args[1] as! Float) }

    sym = create(name: ">=" , type: ff2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Float) >= (args[1] as! Float) }

    sym = create(name: "="  , type: ff2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Float) == (args[1] as! Float) }

    semantics[sym] = { (args: [Any]) in (args[0] as! Float) != (args[1] as! Float) }
    sym = create(name: "!=" , type: ff2b, overloadable: true)

    semantics[sym] = { (args: [Any]) in +(args[0] as! Float) }
    sym = create(name: "+"  , type: f2f , overloadable: true)

    sym = create(name: "-"  , type: f2f , overloadable: true)
    semantics[sym] = { (args: [Any]) in -(args[0] as! Float) }

    sym = create(name: "+"  , type: ff2f, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Float) + (args[1] as! Float) }

    sym = create(name: "-"  , type: ff2f, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Float) - (args[1] as! Float) }

    sym = create(name: "*"  , type: ff2f, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Float) * (args[1] as! Float) }

    sym = create(name: "/"  , type: ff2f, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! Float) / (args[1] as! Float) }

    sym = create(name: "<"  , type: ss2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! String) < (args[1] as! String) }

    sym = create(name: "<=" , type: ss2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! String) <= (args[1] as! String) }

    sym = create(name: ">"  , type: ss2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! String) > (args[1] as! String) }

    sym = create(name: ">=" , type: ss2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! String) >= (args[1] as! String) }

    sym = create(name: "="  , type: ss2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! String) == (args[1] as! String) }

    sym = create(name: "!=" , type: ss2b, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! String) != (args[1] as! String) }

    sym = create(name: "+"  , type: ss2s, overloadable: true)
    semantics[sym] = { (args: [Any]) in (args[0] as! String) + (args[1] as! String) }
  }

  private unowned var context: ASTContext
  public private(set) var semantics: [Symbol: ([Any]) -> Any] = [:]

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
