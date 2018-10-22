import AST
import Parser
import Sema
import Utils

func excerpt(of range: SourceRange) -> String? {
  guard let lines = try? range.start.source.read(lines: range.start.line)
    else { return nil }
  guard lines.count == range.start.line
    else { return nil }

  var result = lines.last! + "\n"
  result += String(repeating: " ", count: range.start.column - 1) + "^"
  if (range.start.line == range.end.line) && (range.end.column - range.start.column > 1) {
    let length = range.end.column - range.start.column - 1
    result += String(repeating: "~", count: length)
  }
  return result + "\n"
}

func diagnose(error: LocatableError, in console: Console) {
  // Determine the category and root cause of the error.
  var range = error.range
  let category: String
  let cause: String

  switch error {
  case let parseError as ParseError:
    category = "syntax error"
    cause = String(describing: parseError.cause)

  case let staticError as ASTError:
    // AST errors represent issues that were detected statically, either during the sanitization of
    // the AST, or during the semantic analysis.
    switch staticError.cause {
    case SAError.unsolvableConstraint(let constraint, let failure):
      // Type constraints can be broken into smaller one, so we use contraint locations to pinpoint
      // the actual cause of the failure, which should be resolved.
      range = resolve(paths: constraint.location.paths, node: constraint.location.anchor)
      category = "type error"

      switch failure {
      case .typeMismatch:
        cause = "type '\(constraint.types!.t)' doesn't match '\(constraint.types!.u)'"
      default:
        cause = String(describing: failure)
      }

    default:
      category = "static error"
      cause = String(describing: staticError.cause)
    }

  default:
    category = "error"
    cause = String(describing: error)
  }

  let errorLocation = range.map { "l.\($0.start.line):c.\($0.start.column)" } ?? ""
  console.write("\(errorLocation): \(category): \(cause):\n")

  // Log the excerpt from the source, if available.
  if range != nil, let snippet = excerpt(of: range!) {
    console.write(snippet)
  }
}

func diagnose<E>(errors: [E], in console: Console) where E: LocatableError {
  for error in errors {
    diagnose(error: error, in: console)
    console.write("\n")
  }
}

func resolve<C>(paths: C, node: Node) -> SourceRange
  where C: Collection, C.Element == ConstraintPath
{
  guard let first = paths.first
    else { return node.range }

  switch first {
  case .body:
    guard let function = node as? Func
      else { unreachable("Invalid path '\(first)' for node '\(node)'") }
    return resolve(paths: paths.dropFirst(), node: function.body)

  case .callee:
    guard let call = node as? Call
      else { unreachable("Invalid path '\(first)' for node '\(node)'") }
    return resolve(paths: paths.dropFirst(), node: call.callee)

  case .else:
    guard let expr = node as? If
      else { unreachable("Invalid path '\(first)' for node '\(node)'") }
    return resolve(paths: paths.dropFirst(), node: expr.elseExpr)

  case .matchValue(let i):
    guard let match = node as? Match, match.cases.count > i
      else { unreachable("Invalid path '\(first)' for node '\(node)'") }
    return resolve(paths: paths.dropFirst(), node: match.cases[i])

  case .then:
    guard let expr = node as? If
      else { unreachable("Invalid path '\(first)' for node '\(node)'") }
    return resolve(paths: paths.dropFirst(), node: expr.thenExpr)

  case .identifier:
    return node.range

  default:
    return node.range
  }
}
