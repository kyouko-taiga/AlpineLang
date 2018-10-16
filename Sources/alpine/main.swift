import Darwin.C

import AST
import Parser
import Sema

let input = """
// type Nat :: zero() or succ(_: Nat)
// func identity (i: Nat) -> Nat :: identity(i: i)
// func f () -> point(x: Nat, y: Nat) :: point(x: zero(), y: zero())

//func a () -> Int :: match (x: 1, y: 2)
//  with (x: let x, y: 2) :: x
func a () -> () -> Int ::
  if true
    then func f () -> Int :: 1
    else func f () -> Int :: 2

func main () -> () :: print()
"""

// Parse the module.
let module: Module
do {
  let parser = try Parser(source: input)
  module = try parser.parse()
} catch let errpr as ParseError {
  diagnose(error: errpr)
  exit(1)
}

// Create the type constraints.
let context = ASTContext()
let passes: [SAPass] = [
  SymbolCreator(context: context),
  NameBinder(context: context),
  ConstraintCreator(context: context),
]
for pass in passes {
  try pass.visit(module)
}

// Print the extracted type constraints (for debugging purpose).
for constraint in context.typeConstraints {
  constraint.prettyPrint()
}
print()

// Solve the type constraints.
var solver = ConstraintSolver(constraints: context.typeConstraints, in: context)
let result = solver.solve()
switch result {
case .success(let solution):
  print(solution)

case .failure(let errors):
  for error in errors {
    context.add(
      error: SAError.unsolvableConstraint(constraint: error.constraint, cause: error.cause),
      on: error.constraint.location.resolved)
  }
}

guard context.errors.isEmpty else {
  // Print the errors, sorted.
  _ = context.errors.map(diagnose)
  exit(1)
}

var output = ""
let dumper = ASTDumper(outputTo: Logger())
try dumper.visit(module)
print(output)
