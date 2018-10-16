/// Locates a constraint within an expression.
///
/// So as to better diagnose inference issues, it is important to keep track of the expression or
/// statement in the AST that engendered a particular condition. Additionally, as constraints may
/// be decomposed during the inference process, we also need to keep track of the location of the
/// constraint that was decomposed.
///
/// We use the same approach as Swift's compiler to tackle this issue:
/// A constraint location is composed of an anchor, that describes the node within the AST from
/// which the constraint originates, and of one or more paths that describe the derivation steps
/// from the anchor.
public struct ConstraintLocation {

  public init(anchor: Node, paths: [ConstraintPath]) {
    precondition(!paths.isEmpty)
    self.anchor = anchor
    self.paths = paths
  }

  /// The node at which the constraint (or the one from which it derivates) was created.
  public let anchor: Node
  /// The path from the anchor to the exact node the constraint is about.
  public let paths: [ConstraintPath]

  /// The resolved path of the location, i.e. the node it actually points to.
  ///
  /// This property is computed by following the paths components from the anchor. For instance, if
  /// if the path is `call -> parameter(0)`, and the anchor is a `CallExpr` of the form `f(x = 2)`,
  /// then the resolved path is the literal `2`.
  ///
  /// If the path can't be followed until then end, the deepest resolved node is returned.
  public var resolved: Node {
    // TODO
    return anchor
  }

  public static func location(_ anchor: Node, _ paths: ConstraintPath...)
    -> ConstraintLocation
  {
    return ConstraintLocation(anchor: anchor, paths: paths)
  }

  public static func + (lhs: ConstraintLocation, rhs: ConstraintPath) -> ConstraintLocation {
    return ConstraintLocation(anchor: lhs.anchor, paths: lhs.paths + [rhs])
  }

}
