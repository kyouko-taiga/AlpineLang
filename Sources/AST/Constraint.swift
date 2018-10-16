import Utils

public enum ConstraintKind: Int {

  /// An equality constraint `T ~= U` that requires `T` to match `U`.
  case equality = 10

  /// A cnformance constraint `T <= U` that requires `T` to be identical to or element of `U`.
  case conformance = 8

  /// A member constraint `T[.name] ~= U` that requires `T` to have a member `name` whose type
  /// matches `U`.
  case member = 4

  /// A disjunction of constraints
  case disjunction = 0

}

/// Describes a derivation step to reach the exact location of a constraint from an anchor node.
public enum ConstraintPath: Equatable {

  /// The type annotation of a parameter declaration.
  case annotation
  /// The body of a function.
  case body
  /// The call site of a function.
  case call
  /// The codomain of a function.
  case codomain
  /// The condition of a conditional expression.
  case condition
  /// The domain of a function.
  case domain
  /// The "else" branch of a conditional expression.
  case `else`
  /// An identifier.
  case identifier
  /// The i-th element of a tuple.
  case element(Int)
  /// The i-th pattern of a match expression.
  case matchPattern(Int)
  /// The ownee of a select expression.
  case select
  /// The signature of a type declaration.
  case signature
  /// The "then" branch of a conditional expression.
  case then
  /// A labeled tuple.
  case tuple
  /// A case of a union type.
  case unionCase
  /// the i-th value of a match expression.
  case matchValue(Int)

}

public struct Constraint {

  public init(
    kind: ConstraintKind,
    types: (t: TypeBase, u: TypeBase)? = nil,
    member: String? = nil,
    choices: [Constraint] = [],
    location: ConstraintLocation)
  {
    self.kind = kind
    self.types = types
    self.member = member
    self.choices = choices
    self.location = location
  }

  /// Creates an equality constraint.
  public static func equality(t: TypeBase, u: TypeBase, at location: ConstraintLocation)
    -> Constraint
  {
    return Constraint(kind: .equality, types: (t, u), location: location)
  }

  /// Creates a conformance constraint.
  public static func conformance(t: TypeBase, u: TypeBase, at location: ConstraintLocation)
    -> Constraint
  {
    return Constraint(kind: .conformance, types: (t, u), location: location)
  }

  /// Creates a member constraint.
  public static func member(
    t: TypeBase,
    member: String,
    u: TypeBase,
    at location: ConstraintLocation) -> Constraint
  {
    return Constraint(kind: .member, types: (t, u), member: member, location: location)
  }

  /// Creates a disjunction constraint.
  public static func disjunction(_ choices: [Constraint], at location: ConstraintLocation)
    -> Constraint
  {
    return Constraint(kind: .disjunction, choices: choices, location: location)
  }

  /// The kind of the constraint.
  public let kind: ConstraintKind
  /// The location of the constraint.
  public let location: ConstraintLocation
  /// The types `T` and `U` of a match-relation constraint.
  public let types: (t: TypeBase, u: TypeBase)?
  /// The name in `T[.name]` of a member constraint.
  public let member: String?
  /// The choices of a disjunction constraint.
  public let choices: [Constraint]

  public static func < (lhs: Constraint, rhs: Constraint) -> Bool {
    return lhs.kind.rawValue < rhs.kind.rawValue
  }

}

extension Constraint {

  public func prettyPrint(level: Int = 0) {
    let ident = String(repeating: " ", count: level * 2)
    let loc = location.anchor.range.start.description
    print(ident + loc + String(repeating: " ", count: 5 - loc.count), terminator: " | ")

    switch kind {
    case .equality:
      print("\(types!.t) ≡ \(types!.u)")
    case .conformance:
      print("\(types!.t) ≤ \(types!.u)")
    case .member:
      print("\(types!.t).\(member!) ≡ \(types!.u)")
    case .disjunction:
      print("")
      for constraint in choices {
        constraint.prettyPrint(level: level + 1)
      }
    }
  }

}
