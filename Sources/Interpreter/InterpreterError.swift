import AST

public enum InterpreterError: Error {

  case staticFailure(errors: [ASTError])

}
