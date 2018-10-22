import AST
import Utils

/// Transformer that normalizes the AST representation.
public final class Normalizer: ASTTransformer {

  public init() {
  }

  public func transform(_ node: Binary) throws -> Node {
    return Call(
      callee: node.op,
      arguments: [
        Arg(
          label : nil,
          value : try transform(node.left) as! Expr,
          module: node.left.module,
          range : node.left.range),
        Arg(
          label : nil,
          value : try transform(node.right) as! Expr,
          module: node.right.module,
          range : node.right.range),
      ],
      module: node.module,
      range : node.range)
  }

  public func transform(_ node: Unary) throws -> Node {
    return Call(
      callee: node.op,
      arguments: [
        Arg(
          label : nil,
          value : try transform(node.operand) as! Expr,
          module: node.operand.module,
          range : node.operand.range),
      ],
      module: node.module,
      range : node.range)
  }

}
