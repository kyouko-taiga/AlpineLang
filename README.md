# Alpine-Lang

Alpine-Lang is the programming language used to express the model semantics in the Alpine Editor.
It is first order,
statically strongly typed,
pure functional programming language.

Although it's a quite expressive language,
Alpine hasn't been developed to be a fully-featured standalone language.
Hence, it does not offer any support for input/output, side effects or concurrency,
which are features expected to be implemented in a model.

## Usage

Although Alpine-Lang is first and foremost designed to be used within the Alpine Editor,
its interpreter can be used offline,
either as a command line tool or as a library.

The whole thing being written in [Swift](https://swift.org),
a working Swift 4.2+ compiler is a requirement to build and/or use Alpine-Lang's interpreter.

### As a Command Line Tool

Download the present repository on your file system and build the `alpine` target
with Swift Package Manager.
Run the following command at the root of the repository (i.e. where `Package.swift` is located).
This will produce an executable `alpine` in the folder `.build/release`,
which you can use from there or move wherever you want.

```bash
swift build -c release
```

You can interpret an expression with the following command:

```bash
./alpine -e '"Hello, World!"'
```

You can add Alpine in your profile to use wherever you want in your terminal.  
Add in your `~/.bash_profile` (*MacOs*) | `~/.profile` or `~/.bashrc` (*Linux*):

```bash
export PATH="/My/Folder/AlpineLang/.build/release:$PATH"
```

Think to update your terminal:  
```bash
source ~/.bash_profile
# or
source ~/.profile
# or
source ~/.bashrc
```

Now you can just call:  

```bash
alpine -e '"Hello, World!"'
```


use the `--import` or `-i` option to specify the path of a module containing additional definitions
such as function and type declarations:

```bash
alpine --import some/module.alpine -e 'my_function(a: 1, b: 2)'
```

Import with the `Examples` folder:

```bash
alpine --import Examples/list.alpine -e 'size(#cons(#zero, #cons(#succ(#zero), #empty)))'
```

Print the **AST** :

```bash
alpine --dump-ast --import Examples/list.alpine -e 'size(#cons(#zero, #cons(#succ(#zero), #empty)))'
```


Help:

```bash
alpine -h
# or
alpine --help
```

### As a Library

You can add Alpine-Lang as a dependency to your project with Swift Package Manager:

```swift
let package = Package(
  name: "AwesomeProject",
  dependencies: [
    .package(url: "https://github.com/kyouko-taiga/AlpineLang.git", .branch("master")),
  ],
  targets: [
    .target(
        name: "AwesomeProject",
        dependencies: ["AlpineLib"]),
    // ...
]
```

This will let you import Alpine-Lan's interpreter in your own code:

```swift
import Interpreter

var interpreter = Interpreter()
let value = try! interpreter.eval(string: "\"Hello, World!\"")
print(value)
```

If you want to load a module:

```swift
import Interpreter

var module: String = """
type Boolean :: #True or #False

func not(_ bool: Boolean) -> Boolean ::
// Not of a boolean
  match(bool)
    with #True ::
      #False
    with #False ::
      #True
"""

var interpreter = Interpreter()
try! interpreter.loadModule(fromString: module)
let code: String = "not(#True)"
let value = try! interpreter.eval(string: code)
// #False
print(value)
```

## Syntax

Alpine-Lang is based on a rather small set of constructions,
which makes the syntax of the language relatively easy to understand.

```ebnf
module          :: { ( func | type ) } ;
type            :: "type", ident, "::", type-sign ;
type-sign       :: func-sign | tuple-sign | union-sign | ident ;
func-sign       :: tuple-sign, "->", type-sign ;
tuple-sign      :: "(", { tuple-sign-elem }, ")" ;
tuple-sign-elem :: [ ( ident | underscore), [ ident ], ":" ], expr ;
union-sign      :: type-sign, { "or", type-sign } ;
expr            :: func | if | match | let-binding | binary | unary | call |
                   tuple | select | ident | string | real | integer | boolean ;
func            :: "func", [ ident ], func-sign "::" expr ;
if              :: "if", expr, "then", expr, "else", expr ;
match           :: "match", expr, match-case, { match-case };
match-case      :: "with", expr, "::", expr ;
let-binding     :: "let", ident ;
binary          :: expr, operator, expr ;
unary           :: operator, expr ;
call            :: expr, "(", { arg }, ")" ;
arg             ::= [ ident, ":" ], expr ;
tuple           ::= "(", { tuple-elem }, ")" ;
tuple-elem      ::= [ ident, ":" ], expr ;
select          ::= expr, ".", expr ;
ident           ::= ( letter | underscore ), { character } ;
string          ::= "\"", character, "\"" ;
real            ::= integer, ".", [ digit ], { digit } ;
integer         ::= "0" | [ "-" ], non-zero-digit, { digit } ;
boolean         ::= "true" | "false" ;
```

## Type System

Alpine-Lang features 4 built-in types:

* `Bool` for boolean values,
* `Int` for integer numbers (represented on 64 bits),
* `Real` for real numbers (represented on 128 bits), and
* `String` for character strings.

In addition to those built-in types,
the language support function types, tuple types and union types,
which can be defined by the user.

Tuple types (and union thereof) are the foundation to express algebraic terms,
which are the basic blocs Alpine-Lang is designed to manipulate.
In fact, they allow the definition of [union types](https://en.wikipedia.org/wiki/Union_type).
Here's an example of the definition of a type representing HTTP responses:

```alpine
type HTTPResponse ::
  #success(payload: String) or
  #error(code: Int)
```

The above definition states that any value of type `HTTPResponse` is either
a tuple of the form `#success(payload: <some character string>)` or
`#error(code: <some number>)`.
Both cases are called the *generators* of the type `HTTPResponse`.

> Notice how tuples are prefixed with a character string starting with `#`,
> which is the syntax Alpine-Lang uses to label tuples.
> Labeling tuples allow for clearer definitions and is encouraged.

Creating a value of type `HTTPResponse` amounts to using one of its generator,
and providing it with the appropriate values:

```alpine
#error(code: 404)
```

While tuple union types allow the definition of algebraic terms,
functions can be used to express axioms between those terms.
Here's an example of a function that extracts the status an `HTTPResponse`:

```alpine
func status(of response: HTTPResponse) -> Int ::
  match response
    with #success(payload: _) :: 200
    with #error(code: let n) :: n
```

> Notice the use of pattern matching to extract values from tuples.

Alpine-Lang is a first order language,
meaning that functions are values just as tuple and built-in values are.
Here's an example of a function that returns a function.

```alpine
func curry(_ fn: (Int, Int) -> Int) -> (Int) -> (Int) -> Int ::
  func (_ a: Int) -> (Int) -> Int ::
    func (_ b: Int) -> Int ::
      fn(a, b)
```
