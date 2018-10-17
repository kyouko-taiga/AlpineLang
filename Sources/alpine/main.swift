import AST
import Interpreter

let input = """
// type Nat :: zero() or succ(_: Nat)
// func main () -> Nat :: succ(zero())

type Nat :: #zero or #succ(_: Nat)
func main () -> Nat :: #succ(#zero)

// func make_point () -> point(x: Nat, y: Nat) :: point(x: zero(), y: zero())
// func recurse (i: Nat) -> Nat :: recurse(i: i)
// func a () -> Int :: match (x: 1, y: 2)
//   with (x: let x, y: 2) :: x
// func a () -> () -> Int ::
//   if true
//     then func f () -> Int :: 1
//     else func f () -> Int :: 2
"""

var interpreter = Interpreter(debug: true)

do {

  let dumper = ASTDumper(outputTo: Logger())

  // Load a module description.
  let module = try interpreter.loadModule(fromString: input)
  dumper.dump(ast: module)
  print()

  // Interpret an expression.
  let val = try interpreter.eval(string: "main()")
  print(val)

} catch InterpreterError.staticFailure(let errors) {
  _ = errors.map(diagnose)
} catch {
  print(error)
}
