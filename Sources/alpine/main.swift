import AST
import Parser
import Interpreter

let input = """
//func main () -> Nat :: #succ(#zero)

//type Pair :: (_: Int, _: Int)
//func first_of(pair: Pair) -> Int :: pair.0

//type Nat :: #zero or #succ(_: Nat)
//
//func + (_ lhs: Nat, _ rhs: Nat) -> Nat ::
//  match (lhs, rhs)
//    with (#zero, let x) :: x
//    with (#succ(let x), let y) :: #succ(x + y)

func factorial (of x: Int) -> Int ::
  if x <= 1
    then 1
    else x * factorial(of: x - 1)
"""

var interpreter = Interpreter(debug: true)

do {

//  let dumper = ASTDumper(outputTo: Logger())
//  let module = try interpreter.loadModule(fromString: input)
//  dumper.dump(ast: module)
//  print()

  // Load a module description.
  try interpreter.loadModule(fromString: input)

  // Interpret an expression.
  let val = try interpreter.eval(string: "factorial(of: 10)")
  print(val)

} catch let error as LocatableError {
  diagnose(error: error, in: Console.err)
} catch InterpreterError.staticFailure(let errors) {
  diagnose(errors: errors, in: Console.err)
} catch {
  print(error)
}
