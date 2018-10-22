import AST

public enum Value {

  /// A boolean value.
  case bool(Bool)
  /// An integer value.
  case int(Int)
  /// A real value.
  case real(Double)
  /// A string value.
  case string(String)
  /// A built-in function.
  case builtinFunction(([Any]) -> Any)
  /// A user function.
  case function(Func, closure: [Symbol: Value])
  /// A tuple.
  case tuple(label: String?, elements: [(label: String?, value: Value)])

}

extension Value {

  /// Create an alpine value from a Swift native value.
  init?(value: Any) {
    switch value {
    case let v as Bool  : self = .bool(v)
    case let v as Int   : self = .int(v)
    case let v as Double: self = .real(v)
    case let v as String: self = .string(v)
    default: return nil
    }
  }

  /// Return the Swift value corresponding to this Alpine value, assuming it is representable as a
  /// Swift native type (e.g. `Int`).
  var swiftValue: Any? {
    switch self {
    case .bool(let value)   : return value
    case .int (let value)   : return value
    case .real(let value)   : return value
    case .string(let value) : return value
    default                 : return nil
    }
  }

}

extension Value: CustomStringConvertible {

  public var description: String {
    switch self {
    case .bool(let value):
      return value.description

    case .int(let value):
      return value.description

    case .real(let value):
      return value.description

    case .string(let value):
      return value

    case .builtinFunction(_):
      return "<built-in function>"

    case .function(let f, closure: _):
      return "<function \(f.type!)>"

    case .tuple(let label, let elements):
      guard (label != nil) || (!elements.isEmpty)
        else { return "()" }
      let elts = elements
        .map({ $0.label != nil ? "#\($0.label!): \($0.value)" : $0.value.description })
        .joined(separator: ", ")
      let prefix = label.map { "#\($0)" } ?? ""
      let suffix = elements.isEmpty ? "" : "(\(elts))"
      return prefix + suffix
    }
  }

}
