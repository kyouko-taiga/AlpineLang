import AST

public final class EvaluationContext {

  public init(_ dictionary: [Symbol: Value]) {
    storage = dictionary
  }

  public init<S>(uniqueKeysWithValues keysAndValues: S)
    where S: Sequence, S.Element == (Symbol, Value)
  {
    storage = Dictionary(uniqueKeysWithValues: keysAndValues)
  }

  public init<S>(_ keysAndValues: S, uniquingKeysWith combine: (Value, Value) throws -> Value)
    rethrows
    where S: Sequence, S.Element == (Symbol, Value)
  {
    storage = try Dictionary(keysAndValues, uniquingKeysWith: combine)
  }

  public func merging(
    _ other: EvaluationContext,
    uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows -> EvaluationContext
  {
    return try EvaluationContext(storage.merging(other.storage, uniquingKeysWith: combine))
  }

  public var copy: EvaluationContext {
    return EvaluationContext(storage)
  }

  public subscript(symbol: Symbol) -> Value? {
    get { return storage[symbol] }
    set { storage[symbol] = newValue }
  }

  private var storage: [Symbol: Value]

}

extension EvaluationContext: Collection {

  public typealias Index = Dictionary<Symbol, Value>.Index
  public typealias Element = Dictionary<Symbol, Value>.Element

  public var startIndex: Index {
    return storage.startIndex
  }

  public var endIndex: Index {
    return storage.endIndex
  }

  public func index(after i: Index) -> Index {
    return storage.index(after: i)
  }

  public subscript(i: Index) -> Element {
    return storage[i]
  }

}

extension EvaluationContext: ExpressibleByDictionaryLiteral {

  public convenience init(dictionaryLiteral elements: (Symbol, Value)...) {
    self.init(uniqueKeysWithValues: elements)
  }

}

extension EvaluationContext: CustomStringConvertible, CustomDebugStringConvertible {

  public var description: String {
    return storage.description
  }

  public var debugDescription: String {
    return storage.debugDescription
  }

}

extension EvaluationContext: CustomReflectable {

  public var customMirror: Mirror {
    return storage.customMirror
  }

}
