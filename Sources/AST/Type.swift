/// Base class for all types in Anzen.
public class TypeBase: Hashable, CustomStringConvertible {

  fileprivate init() {}

  /// The metatype of the type.
  public lazy var metatype: Metatype = { [unowned self] in
    return Metatype(of: self)
  }()

  public var hashValue: Int {
    return 0
  }

  public var description: String {
    var memo = Set<TupleType>()
    return serialize(memo: &memo)
  }

  public static func == (lhs: TypeBase, rhs: TypeBase) -> Bool {
    return lhs === rhs
  }

  fileprivate func serialize(memo: inout Set<TupleType>) -> String {
    return String(describing: self)
  }

}

/// Class to represent the description of a type.
public final class Metatype: TypeBase {

  fileprivate init(of type: TypeBase) {
    self.type = type
  }

  public let type: TypeBase

  fileprivate override func serialize(memo: inout Set<TupleType>) -> String {
    return "\(type.serialize(memo: &memo)).metatype"
  }

}

/// A special type that's used to represent a typing failure.
public final class ErrorType: TypeBase {

  public static let get = ErrorType()

  fileprivate override func serialize(memo: inout Set<TupleType>) -> String {
    return "<error type>"
  }

}

/// Class to represent the built-in types.
public final class BuiltinType: TypeBase {

  private init(name: String) {
    self.name = name
  }

  public let name: String

  public override var hashValue: Int {
    return name.hashValue
  }

  fileprivate override func serialize(memo: inout Set<TupleType>) -> String {
    return name
  }

  public static let bool   = BuiltinType(name: "Bool")
  public static let int    = BuiltinType(name: "Int")
  public static let float  = BuiltinType(name: "Float")
  public static let string = BuiltinType(name: "String")

}

/// A type variable used during type checking.
public final class TypeVariable: TypeBase {

  public override init() {
    self.id = TypeVariable.nextID
    TypeVariable.nextID += 1
  }

  public let id: Int
  private static var nextID = 0

  public override var hashValue: Int {
    return id
  }

  fileprivate override func serialize(memo: inout Set<TupleType>) -> String {
    return "$\(id)"
  }

}

/// Class to represent function types.
public final class FunctionType: TypeBase {

  internal init(domain: TupleType, codomain: TypeBase) {
    self.domain = domain
    self.codomain = codomain
  }

  /// The domain of the function.
  public let domain: TupleType
  /// The codomain of the function.
  public let codomain: TypeBase

  fileprivate override func serialize(memo: inout Set<TupleType>) -> String {
    return "\(domain.serialize(memo: &memo)) -> \(codomain.serialize(memo: &memo))"
  }

}

/// Class to represent tuple types.
public final class TupleType: TypeBase {

  internal init(label: String?, elements: [TupleTypeElem]) {
    self.label = label
    self.elements = elements
  }

  /// The label of the type.
  public let label: String?
  /// The elements of the type.
  public var elements: [TupleTypeElem]

  fileprivate override func serialize(memo: inout Set<TupleType>) -> String {
    guard !memo.contains(self)
      else { return "..." }
    memo.insert(self)

    let elements = self.elements
      .map({ ($0.label ?? "_") + ": \($0.type.serialize(memo: &memo))" })
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
public final class UnionType: TypeBase {

  internal init(cases: Set<TypeBase>) {
    self.cases = cases
  }

  public let cases: Set<TypeBase>

  fileprivate override func serialize(memo: inout Set<TupleType>) -> String {
    let cases = self.cases
      .map({ $0.serialize(memo: &memo) })
      .joined(separator: " or ")
    return "( \(cases) )"
  }


  public static func == (lhs: UnionType, rhs: UnionType) -> Bool {
    return lhs.cases == rhs.cases
  }

}
