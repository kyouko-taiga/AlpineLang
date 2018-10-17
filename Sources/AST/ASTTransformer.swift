public protocol ASTTransformer {

  func transform(_ node: Module)          throws -> Node

  // MARK: Declarations

  func transform(_ node: Func)            throws -> Node
  func transform(_ node: TypeAlias)       throws -> Node

  // MARK: Type signatures

  func transform(_ node: FuncSign)        throws -> Node
  func transform(_ node: TupleSign)       throws -> Node
  func transform(_ node: TupleSignElem)   throws -> Node
  func transform(_ node: UnionSign)       throws -> Node
  func transform(_ node: TypeIdent)       throws -> Node

  // MARK: Expressions

  func transform(_ node: If)              throws -> Node
  func transform(_ node: Match)           throws -> Node
  func transform(_ node: MatchCase)       throws -> Node
  func transform(_ node: LetBinding)      throws -> Node
  func transform(_ node: Binary)          throws -> Node
  func transform(_ node: Unary)           throws -> Node
  func transform(_ node: Call)            throws -> Node
  func transform(_ node: Arg)             throws -> Node
  func transform(_ node: Tuple)           throws -> Node
  func transform(_ node: TupleElem)       throws -> Node
  func transform(_ node: Select)          throws -> Node
  func transform(_ node: Ident)           throws -> Node
  func transform(_ node: Scalar<Bool>)    throws -> Node
  func transform(_ node: Scalar<Int>)     throws -> Node
  func transform(_ node: Scalar<Double>)  throws -> Node
  func transform(_ node: Scalar<String>)  throws -> Node

}
