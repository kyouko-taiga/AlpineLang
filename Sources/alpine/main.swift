import Foundation

import ArgParse
import AST
import Parser
import Interpreter

private func run(_ block: () throws -> Void) {
  do {
    try block()
  } catch let error as LocatableError {
    diagnose(error: error, in: Console.err)
  } catch InterpreterError.staticFailure(let errors) {
    diagnose(errors: errors, in: Console.err)
  } catch {
    print(error)
  }
}

// Parse the command line arguments.

private let parser: ArgumentParser = [
  .positional("input"              , description: "path to a file with the expression to execute"),
  .option    ("import" , alias: "i", description: "import a module"),
  .option    ("exec"   , alias: "e", description: "execute the given expression"),
  .flag      ("verbose", alias: "v", description: "output various compiler debug info"),
  .flag      ("help"   , alias: "h", description: "show this help"),
]

private let parseResult: ArgumentParser.ParseResult
do {
  parseResult = try parser.parse(CommandLine.arguments)
} catch let error as ArgumentParserError {
  switch error {
  case .emptyCommandLine:
    Console.err.print("error: command line is empty")
  case .missingArguments:
    Console.err.print("error: no input file")
  case .unexpectedArgument(let arg):
    Console.err.print("error: unexpected argument '\(arg)'")
  case .invalidArity(let arg, _):
    Console.err.print("error: invalid value for argument '\(arg.name)'")
  }
  exit(-1)
}

guard !(parseResult["help"] as! Bool) else {
  parser.printUsage(to: &Console.out)
  exit(0)
}

let verbose = parseResult["verbose"] as! Bool
var interpreter = Interpreter(debug: verbose)
let dumper = ASTDumper(outputTo: Console.err)

// Load the module if provided.
if let modulePath = parseResult["import"] as? String {
  let moduleText = try String(contentsOfFile: modulePath, encoding: .utf8)

  run {
    let module = try interpreter.loadModule(fromString: moduleText)
    if verbose {
      dumper.dump(ast: module)
    }
  }
}

// Execute the given expression.
let val: Value
if let exprText = parseResult["exec"] as? String {
  val = try interpreter.eval(string: exprText)
} else if let exprPath = parseResult["input"] as? String {
  let exprText = try String(contentsOfFile: exprPath)
  val = try interpreter.eval(string: exprText)
} else {
  Console.err.print("error: no input")
  exit(-1)
}

Console.out.print(val)
