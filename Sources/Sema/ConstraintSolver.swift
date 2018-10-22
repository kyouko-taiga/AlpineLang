import AST
import Utils

// let SOLVER_TIMEOUT: Stopwatch.TimeInterval? = Stopwatch.TimeInterval(s: 10)
let SOLVER_TIMEOUT: Stopwatch.TimeInterval? = nil

public struct ConstraintSolver {

  public init<S>(constraints: S, in context: ASTContext, assumptions: SubstitutionTable = [:])
    where S: Sequence, S.Element == Constraint
  {
    self.context = context
    self.constraints = constraints.sorted(by: <)
    self.assumptions = assumptions
  }

  /// The AST context.
  public let context: ASTContext
  // The constraints that are yet to be solved.
  private var constraints: [Constraint]
  // The assumptions made so far on the free types of the AST.
  private var assumptions: SubstitutionTable

  private typealias Success = SubstitutionTable
  private typealias Failure = (constraint: Constraint, cause: SolverResult.FailureKind)

  /// Attempts to solve a set of typing constraints, returning either a solution or the constraints
  /// that couldn't be satisfied.
  public mutating func solve() -> SolverResult {
    let stopwatch = Stopwatch()

    while let constraint = constraints.popLast() {
      guard (SOLVER_TIMEOUT == nil) || (stopwatch.elapsed < SOLVER_TIMEOUT!)
        else { return .failure([(reify(constraint: constraint), .timeout)]) }

      switch constraint.kind {
      case .equality, .conformance:
        guard solve(match: constraint) == .success else {
          return .failure([(reify(constraint: constraint), .typeMismatch)])
        }

        // FIXME: Instead of returning upon failure, we should bind variables to `<type error>` and
        // try to solve the remainder of the constraints. This would make for more comprehensive
        // diagnostics as it would let us detect additional errors as well.

      case .member:
        guard solve(member: constraint) == .success else {
          return .failure([(reify(constraint: constraint), .typeMismatch)])
        }

      case .disjunction:
        // Solve each branch with a sub-solver.
        var results: [SolverResult] = []
        for choice in constraint.choices {
          var subsolver = ConstraintSolver(
            constraints: constraints + [choice],
            in: context,
            assumptions: assumptions)
          results.append(subsolver.solve())
        }

        // Collect all valid solutions.
        var valid = results.compactMap { result -> Success? in
          guard case .success(let solution) = result else { return nil }
          return solution
        }

        switch valid.count {
        case 0:
          let unsolvable = results.compactMap { result -> [Failure]? in
            guard case .failure(let cause) = result else { return nil }
            return cause
          }
          return .failure(Array(unsolvable.joined()))

        case 1:
          return .success(solution: valid[0])

        default:
          // If there are several solutions, we have to try selecting the most specific one. Note
          // that it is possible for two solvers to find the same solution, as one may have received
          // a constraint that didn't add any information to the assumptions. Hence the first step
          // is to identify duplicates.
          var candidates: [Success] = []
          for solution in valid {
            let candidate = solution.reified(in: context)
            // Yep, this is a an ugly linear search! But We work on the assumption that the size of
            // the list of solutions doesn't justify the use of a more sophisticated technique.
            if !candidates.contains(where: { $0.isEquivalent(to: candidate) }) {
              candidates.append(candidate)
            }
          }

          assert(candidates.count > 0)
          if candidates.count == 1 {
            return .success(solution: candidates[0])
          }

          // There are equivalent *different* solutions; the constraint system is ambiguous.
          return .failure([(reify(constraint: constraint), .ambiguousExpression)])
        }
      }
    }

    return .success(solution: assumptions)
  }

  /// Attempts to match `T` and `U`, effectively solving a given constraint between those types.
  private mutating func solve(match constraint: Constraint) -> TypeMatchResult {
    // Get the substitutions we already inferred for `T` and `U` if they are type variables.
    let a = assumptions.substitution(for: constraint.types!.t)
    let b = assumptions.substitution(for: constraint.types!.u)

    // If the types are obviously equivalent, we're done.
    guard a != b else { return .success }

    switch (a, b) {
    case (let var_ as TypeVariable, _):
      if constraint.kind == .conformance && b is TypeVariable {
        // If both `T` and `U` are unknown, we can't solve the conformance constraint yet.
        constraints.insert(constraint, at: 0)
        return .success
      }

      // ASSUMPTION: Even in the case of a conformance match, we can unify `T` with `U` if the
      // former's unknown, as any constraint that would require `T > U` would leave to an invalid
      // program. In other words, we assume `T = join(T, U)` if `T` is a type variable. If this
      // assumption's proved wrong, we'll have to actually compute the "join" of `T` and `U`, using
      // `U` as the upper bound.
      assumptions.set(substitution: b, for: var_)
      return .success

    case (_, let var_ as TypeVariable):
      if constraint.kind == .conformance {
        // ASSUMPTION: If only the right type of a conformance match is unknown, we unify it with
        // the left side on the assumption that `U` should already have been unified with a larger
        // type if it had to. If this assumption's proved wrong, we'll have to create an equality
        // constraint that could match the left type with a union that contains it, as well as
        // what's still unknown at this point.
        assumptions.set(substitution: a, for: var_)
        return .success
      }

      assumptions.set(substitution: a, for: var_)
      return .success

    case (_, let union as UnionType):
      // Get the substitutions we already inferred for the cases of the union
      let cases = union.cases.map(assumptions.substitution)

      if let left = a as? UnionType {
        // An equality or conformance constraint between unions requires us to pair each element of
        // the left with an equivalent type on the right. However, there might be some types that
        // are still unknown but could potentionally be matched with one of the type on the right.
        // One way to do that is to break the constraint into conformance conformance constraints
        // for each of the members of the union.
        for type in left.cases {
          constraints.append(.conformance(t: type, u: union, at: constraint.location + .unionCase))
        }
        return .success
      }

      // Obviously, an equality constraint can't be solved if the `T` isn't a union.
      guard constraint.kind == .conformance
        else { return .failure }

      if cases.contains(a) {
        // The conformance succeeds if `T` is member of `U`.
        return .success

        // IDEA: Note that solving a conformance with `U` being a union doesn't add any information
        // to our assumptions. However, if `U` isn't fully inferred (i.e. still contains unknown
        // types), we may be able to use such conformance constraints to infer some of the missing
        // information.
      }

      // If we can't find `T` in `U`, it might be that `U` contains types that aren't reified or
      // fully infered yet. Hence we should break the constraint into a disjunction of conformances
      // for each case of the union.
      let choices = union.cases.map { Constraint.conformance(t: a, u: $0, at: constraint.location) }
      constraints.insert(.disjunction(choices, at: constraint.location), at: 0)
      return .success

    case (let fl as FunctionType, let fr as FunctionType):
      // Simplify the constraint.
      constraints.append(Constraint(
        kind: constraint.kind,
        types: (fl.domain, fr.domain),
        location: constraint.location + ConstraintPath.domain))
      constraints.append(Constraint(
        kind: constraint.kind,
        types: (fl.codomain, fr.codomain),
        location: constraint.location + ConstraintPath.codomain))
      return .success

    case (let tl as TupleType, let tr as TupleType):
      // Tuple types never match if they have different lenghts or labels.
      guard
        tl.label == tr.label,
        tl.elements.count == tr.elements.count,
        zip(tl.elements, tr.elements).all(satisfy: { $0.0.label == $0.1.label }) else
      { return .failure }

      // Simplify the constraint.
      for (i, elements) in zip(tl.elements, tr.elements).enumerated() {
        constraints.append(Constraint(
          kind: constraint.kind,
          types: (elements.0.type, elements.1.type),
          location: constraint.location + .elementIndex(i)))
      }
      return .success

    case (let ml as Metatype, let mr as Metatype):
      // Simplify the constraint.
      constraints.append(Constraint(
        kind: constraint.kind,
        types: (ml.type, mr.type),
        location: constraint.location))
      return .success

    default:
      return .failure
    }
  }

  /// Attempts to solve `T[.ownee] ~= U`.
  private mutating func solve(member constraint: Constraint) -> TypeMatchResult {
    let owner = assumptions.substitution(for: constraint.types!.t)
    switch owner {
    case is TypeVariable:
      // If the owner's type is unknown, we can't solve the constraint yet.
      constraints.insert(constraint, at: 0)
      return .success

    case let tupleType as TupleType:
      // Look for the member corresponding to `ownee`.
      let element: TupleTypeElem?
      switch constraint.member! {
      case .label(let label):
        element = tupleType.elements.first(where: { $0.label == label })
        guard element != nil
          else { return .failure }
      case .index(let index):
        guard index < tupleType.elements.count
          else { return .failure }
        element = tupleType.elements[index]
      }

      // Break the constraint.
      constraints.append(
        .equality(t: constraint.types!.u, u: element!.type, at: constraint.location))
      return .success

    default:
      return .failure
    }
  }

  /// Reify the types of a constraint.
  private func reify(constraint: Constraint) -> Constraint {
    return Constraint(
      kind: constraint.kind,
      types: constraint.types.map({ (t, u) -> (TypeBase, TypeBase) in
        let a = assumptions.reify(type: t, in: context)
        let b = assumptions.reify(type: u, in: context)
        return (a, b)
      }),
      member: constraint.member,
      choices: constraint.choices.map(reify),
      location: constraint.location)
  }

}

private enum TypeMatchResult {

  case success
  case failure

}

public enum SolverResult {

  public enum FailureKind {
    case ambiguousExpression
    case timeout
    case typeMismatch
  }

  case success(solution: SubstitutionTable)
  case failure([(constraint: Constraint, cause: FailureKind)])

  public var isSuccess: Bool {
    if case .success = self {
      return true
    }
    return false
  }

}
