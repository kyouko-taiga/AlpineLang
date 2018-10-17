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
  /// A function.
  case function(Func)
  /// A tuple.
  case tuple(label: String?, elements: [(label: String?, value: Value)])

}
