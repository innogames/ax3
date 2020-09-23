package ax3.filters;

import ax3.ParseTree.Binop;

class RewriteAssignOps extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			// int/uint /= int/uint/Number
			case TEBinop(a = {type: TTInt | TTUint}, OpAssignOp(AOpDiv(t)), b):
				if (!canBeRepeated(a)) {
					throwError(exprPos(a), "left side of `/=` must be safe to repeat");
				}

				var op:Binop = OpDiv(t.clone());

				var leftSide = cloneExpr(a);
				removeLeadingTrivia(leftSide);
				var eValue = mk(TEBinop(leftSide, op, b.with(expectedType = TTNumber)), TTNumber, a.type);

				e.with(kind = TEBinop(
					a,
					OpAssign(new Token(0, TkEquals, "=", [], [whitespace])),
					eValue
				));

			// int/uint %= Number
			// int/uint *= Number
			case TEBinop(a = {type: TTInt | TTUint}, OpAssignOp(aop = (AOpMod(_) | AOpMul(_))), b = {type: TTNumber}):
				if (!canBeRepeated(a)) {
					throwError(exprPos(a), "left side of `%=` and `*=` must be safe to repeat");
				}

				var op:Binop = switch aop {
					case AOpMod(t): OpMod(t.clone());
					case AOpMul(t): OpMul(t.clone());
					case _: throw "assert";
				}

				var leftSide = cloneExpr(a);
				removeLeadingTrivia(leftSide);
				var eValue = mk(TEBinop(leftSide, op, b.with(expectedType = TTNumber)), TTNumber, a.type);

				e.with(kind = TEBinop(
					a,
					OpAssign(new Token(0, TkEquals, "=", [], [whitespace])),
					eValue
				));

			// ||=
			// &&=
			case TEBinop(a, OpAssignOp(aop = (AOpAnd(_) | AOpOr(_))), b):
				if (!canBeRepeated(a)) {
					throwError(exprPos(a), "left side of `||=` and `&&=` must be safe to repeat");
				}

				var op:Binop = switch aop {
					case AOpAnd(t): OpAnd(t.clone());
					case AOpOr(t): OpOr(t.clone());
					case _: throw "assert";
				}

				var leftSide = cloneExpr(a);
				removeLeadingTrivia(leftSide);
				var eValue = mk(TEBinop(leftSide, op, b), a.type, a.expectedType);

				e.with(kind = TEBinop(
					a,
					OpAssign(new Token(0, TkEquals, "=", [], [whitespace])),
					eValue
				));

			case _:
				e;
		}
	}
}
