/// Base class for all types in Anzen.
public class TypeBase: Hashable {

  fileprivate init() {}

  /// The metatype of the type.
  public lazy var metatype: Metatype = { [unowned self] in
    return Metatype(of: self)
  }()

  public var hashValue: Int {
    return 0
  }

  public static func == (lhs: TypeBase, rhs: TypeBase) -> Bool {
    return lhs === rhs
  }

}

/// Class to represent the description of a type.
public final class Metatype: TypeBase, CustomStringConvertible {

  fileprivate init(of type: TypeBase) {
    self.type = type
  }

  public let type: TypeBase

  public var description: String {
    return "\(type).metatype"
  }

}

/// A special type that's used to represent a typing failure.
public final class ErrorType: TypeBase, CustomStringConvertible {

  public static let get = ErrorType()

  public let description = "<error type>"

}

/// Class to represent the built-in types.
public final class BuiltinType: TypeBase, CustomStringConvertible {

  private init(name: String) {
    self.name = name
  }

  public let name: String

  public override var hashValue: Int {
    return name.hashValue
  }

  public var description: String {
    return name
  }

  public static let bool   = BuiltinType(name: "Bool")
  public static let int    = BuiltinType(name: "Int")
  public static let float  = BuiltinType(name: "Float")
  public static let string = BuiltinType(name: "String")

}

/// A type variable used during type checking.
public final class TypeVariable: TypeBase, CustomStringConvertible {

  public override init() {
    self.id = TypeVariable.nextID
    TypeVariable.nextID += 1
  }

  public let id: Int
  private static var nextID = 0

  public override var hashValue: Int {
    return id
  }

  public var description: String {
    return "$\(id)"
  }

}

/// Class to represent function types.
public final class FunctionType: TypeBase, CustomStringConvertible {

  internal init(domain: TupleType, codomain: TypeBase) {
    self.domain = domain
    self.codomain = codomain
  }

  /// The domain of the function.
  public let domain: TupleType
  /// The codomain of the function.
  public let codomain: TypeBase

  public var description: String {
    return "\(domain) -> \(codomain)"
  }

}

/// Class to represent tuple types.
public final class TupleType: TypeBase, CustomStringConvertible {

  internal init(label: String?, elements: [TupleTypeElem]) {
    self.label = label
    self.elements = elements
  }

  /// The label of the type.
  public let label: String?
  /// The elements of the type.
  public var elements: [TupleTypeElem]

  public var description: String {
    let elements = self.elements
      .map({ ($0.label ?? "_") + ": \($0.type)" })
      .joined(separator: ", ")

    return label != nil
      ? "\(label!)(\(elements))"
      : "(\(elements))"
  }

  public static func == (lhs: TupleType, rhs: TupleType) -> Bool {
    return (lhs.label == rhs.label) && (lhs.elements == rhs.elements)
  }

}

/// The element of a tuple type.
public struct TupleTypeElem: Equatable, CustomStringConvertible {

  public init(label: String?, type: TypeBase) {
    self.label = label
    self.type = type
  }

  public let label: String?
  public let type: TypeBase

  public var description: String {
    return "\(label ?? "_"): \(type)"
  }

  public static func == (lhs: TupleTypeElem, rhs: TupleTypeElem) -> Bool {
    return (lhs.label == rhs.label) && (lhs.type == rhs.type)
  }

}

/// Class to represent union types.
public final class UnionType: TypeBase, CustomStringConvertible {

  internal init(cases: Set<TypeBase>) {
    self.cases = cases
  }

  public let cases: Set<TypeBase>

  public var description: String {
    return "(" + cases.map({ String(describing: $0) }).joined(separator: " or ") + ")"
  }

  public static func == (lhs: UnionType, rhs: UnionType) -> Bool {
    return lhs.cases == rhs.cases
  }

}
