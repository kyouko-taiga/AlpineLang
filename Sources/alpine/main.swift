import AST
import Parser
import Interpreter

let moduleText = """
//type Pair :: (_: Int, _: Int)
//func first_of(pair: Pair) -> Int :: pair.0

type List :: #empty or #cons(Int, List)

func filter (_ list: List, where predicate: (_: Int) -> Bool) -> List ::
  match list
    with #empty :: #empty
    with #cons(let head, let tail) ::
    if predicate(head)
      then #cons(head, filter(tail, where: predicate))
      else filter(tail, where: predicate)

func + (_ lhs: List, _ rhs: List) -> List ::
  match (lhs, rhs)
    with (#empty, let y) :: y
    with (#cons(let head, let tail), let y) ::
      #cons(head, tail + y)

func sort (_ list: List) -> List ::
  match list
    with #empty :: #empty
    with #cons(let head, let tail) ::
      sort(filter(tail, where: func (_ x: Int) -> Bool :: x < head)) +
      #cons(head, sort(filter(tail, where: func (_ x: Int) -> Bool :: x >= head)))
"""

let exprText = """
sort(#cons(1, #cons(3, #cons(2, #cons(4, #empty)))))
"""


var interpreter = Interpreter(debug: false)

do {

//  let dumper = ASTDumper(outputTo: Logger())
//  let module = try interpreter.loadModule(fromString: moduleText)
//  dumper.dump(ast: module)
//  print()

  // Load a module description.
  try interpreter.loadModule(fromString: moduleText)

  // Interpret an expression.
  let val = try interpreter.eval(string: exprText)
  print(val)

} catch let error as LocatableError {
  diagnose(error: error, in: Console.err)
} catch InterpreterError.staticFailure(let errors) {
  diagnose(errors: errors, in: Console.err)
} catch {
  print(error)
}
