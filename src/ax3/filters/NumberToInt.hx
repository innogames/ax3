package ax3.filters;

class NumberToInt extends AbstractFilter {
	public static final tStdInt = TTFun([TTNumber], TTInt);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			// intExpr /= something
			case TEBinop(a = {type: TTInt | TTUint}, OpAssignOp(AOpDiv(divToken)), b):
				if (!canBeRepeated(a)) throwError(exprPos(a), "TODO: tempvar /= left-side");
				var eDiv = coerceToInt(mk(TEBinop(a, OpDiv(mkTokenWithSpaces(TkSlash, "/")), b), TTNumber, a.type));
				mk(TEBinop(a, OpAssign(new Token(0, TkEquals, "=", divToken.leadTrivia, divToken.trailTrivia)), eDiv), a.type, a.type);

			case _:
				switch [e.type, e.expectedType] {
					case [TTNumber, TTInt | TTUint]:
						coerceToInt(e);
					case _:
						e;
				}
		}
	}

	static function coerceToInt(e:TExpr):TExpr {
		var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
		var call = mkCall(stdInt, [e.with(expectedType = TTNumber)]);
		processTrailingToken(t -> t.trailTrivia = removeTrailingTrivia(e), call);
		return call;
	}
}
