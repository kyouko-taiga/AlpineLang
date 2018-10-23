# Alpine-Lang

Alpine-Lang is the programming language used to express the model semantics in the Alpine Editor.
It is first order,
statically strongly typed,
pure functional programming language.

Although it's a quite expressive language,
Alpine hasn't been developed to be a fully-featured standalone language.
Hence, it does not offer any support for input/output, side effects or concurrency,
which are features expected to be implemented in a model.

## Syntax

Alpine-Lang is based on a rather small set of constructions,
which makes the syntax of the language relatively easy to understand.

```
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
match           :: "match", expr, match-case, { match-case },
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
