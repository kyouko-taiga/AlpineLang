public protocol ASTVisitor {

  func visit(_ node: Module)          throws

  // MARK: Declarations

  func visit(_ node: Func)            throws
  func visit(_ node: TypeAlias)       throws

  // MARK: Type signatures

  func visit(_ node: FuncSign)        throws
  func visit(_ node: TupleSign)       throws
  func visit(_ node: TupleSignElem)   throws
  func visit(_ node: UnionSign)       throws
  func visit(_ node: TypeIdent)       throws

  // MARK: Expressions

  func visit(_ node: If)              throws
  func visit(_ node: Match)           throws
  func visit(_ node: MatchCase)       throws
  func visit(_ node: LetBinding)      throws
  func visit(_ node: Binary)          throws
  func visit(_ node: Unary)           throws
  func visit(_ node: Call)            throws
  func visit(_ node: Arg)             throws
  func visit(_ node: Tuple)           throws
  func visit(_ node: TupleElem)       throws
  func visit(_ node: Select)          throws
  func visit(_ node: Ident)           throws
  func visit(_ node: Scalar<Bool>)    throws
  func visit(_ node: Scalar<Int>)     throws
  func visit(_ node: Scalar<Double>)  throws
  func visit(_ node: Scalar<String>)  throws

}
