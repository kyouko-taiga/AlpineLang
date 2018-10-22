import Utils

/// Cass that holds metadata to be associated with an AST.
public final class ASTContext {

  public init() {
  }

  // MARK: Modules

  /// The loaded modules in the context.
  public var modules: [Module] = []

  // MARK: Types

  /// The type constraints that haven't been solved yet.
  public var typeConstraints: [Constraint] = []
  /// The function types in the context.
  private var functionTypes: [FunctionType] = []
  /// The tuple types in the context.
  private var tupleTypes: [TupleType] = []
  /// The union types in the context.
  private var unionTypes: [UnionType] = []

  public func add(constraint: Constraint) {
    typeConstraints.append(constraint)
  }

  /// Retrieves or create a function type.
  public func getFunctionType(from domain: TupleType, to codomain: TypeBase) -> FunctionType {
    if let type = functionTypes.first(where: {
      return ($0.domain == domain)
          && ($0.codomain == codomain)
    }) {
      return type
    }
    let type = FunctionType(domain: domain, codomain: codomain)
    functionTypes.append(type)
    return type
  }

  /// Retrieves or create a tuple type.
  public func getTupleType(label: String?, elements: [TupleTypeElem]) -> TupleType {
    if let type = tupleTypes.first(where: {
      return ($0.label == label)
          && ($0.elements == elements)
    }) {
      return type
    }
    let type = TupleType(label: label, elements: elements)
    tupleTypes.append(type)
    return type
  }

  /// Retrieves or create a union type.
  public func getUnionType(cases: Set<TypeBase>) -> UnionType {
    if let type = unionTypes.first(where: {
      $0.cases == cases
    }) {
      return type
    }
    let type = UnionType(cases: flatten(cases))
    unionTypes.append(type)
    return type
  }

  private func flatten(_ cases: Set<TypeBase>) -> Set<TypeBase> {
    var result: Set<TypeBase> = []
    for type in cases {
      if let union = type as? UnionType {
        result.formUnion(flatten(union.cases))
      } else {
        result.insert(type)
      }
    }
    return result
  }

  // MARK: Built-ins

  public lazy var builtinScope: BuiltinScope = { [unowned self] in
    return BuiltinScope(context: self)
  }()

  // MARK: Diagnostics

  /// The list of errors encountered during the processing of the AST.
  public var errors: [ASTError] = []

  public func add(error: ASTError) {
    errors.append(error)
  }

  public func add(error: Any, on node: Node) {
    errors.append(ASTError(cause: error, node: node))
  }

}

/// An error associated with an AST node.
public struct ASTError {

  public init(cause: Any, node: Node) {
    self.cause = cause
    self.node = node
  }

  public let cause: Any
  public let node: Node

}
