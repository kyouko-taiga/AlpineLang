import AST
import Parser
import Sema
import Utils

func diagnose(range: SourceRange) {
  let lines = try! range.start.source.read(lines: range.start.line)
  guard lines.count == range.start.line else { return }

  print(lines.last!)

  print(String(repeating: " ", count: range.start.column - 1), terminator: "")
  print("^", terminator: "")
  if (range.start.line == range.end.line) && (range.end.column - range.start.column > 1) {
    let length = range.end.column - range.start.column - 1
    print(String(repeating: "~", count: length))
  } else {
    print()
  }
}

func diagnose(error: ASTError) {
  let range = error.node.range
  let title = "\(range.start.line)::\(range.start.column) error:"

  // Diagnose the cause of the error.
  switch error.cause {
  case let semaError as SAError:
    print(title)
    print(semaError)
    diagnose(range: range)

  default:
    print(error.cause)
    diagnose(range: range)
  }
}

func diagnose(error: ParseError) {
  if let range = error.range {
    print("\(range.start.line)::\(range.start.column) error: \(error.cause)")
    diagnose(range: range)
  } else {
    print("error: \(error.cause)")
  }
}

//func diagnoseSolvingFailure(constraint: Constraint, cause: SolverResult.FailureKind) {
//  assert(constraint.kind != .disjunction)
//  assert(!constraint.location.paths.isEmpty)
//
//  switch constraint.location.paths.last! {
//  case .rvalue:
//    // An "r-value" location describes a constraint that failed because the r-value of a binding
//    // statement isn't compatible with the l-value.
//    let (t, u) = constraint.types!
//    System.err.print("cannot assign to type '\(u)' value of type '\(t)'".styled("bold"))
//
//  default:
//    constraint.prettyPrint(in: System.err)
//  }
//
//  System.err.diagnose(range: constraint.location.resolved.range)
//}
