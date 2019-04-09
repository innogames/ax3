package ax3.filters;

class NumberToInt extends AbstractFilter {
	static final tStdInt = TTFun([TTNumber], TTInt);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch [e.type, e.expectedType] {
			case [TTNumber, TTInt | TTUint]:
				var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
				var call = mkCall(stdInt, [e]);
				processTrailingToken(t -> t.trailTrivia = removeTrailingTrivia(e), call);
				call;

			case _:

				switch e.kind {
					case TECast({syntax: syntax, expr: expr = {type: TTNumber}, type: TTInt | TTUint}):
						var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
						e.with(kind = TECall(stdInt, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));

					case TEBinop(a = {type: TTInt | TTUint}, OpAssignOp(AOpDiv(divToken)), b):
						if (!canBeRepeated(a)) {
							throwError(exprPos(a), "TODO: tempvar /= left-side");
						}
						var eDiv = mk(TEBinop(a, OpDiv(mkTokenWithSpaces(TkSlash, "/")), b), TTNumber, a.type);
						mk(TEBinop(a, OpAssign(new Token(0, TkEquals, "=", divToken.leadTrivia, divToken.trailTrivia)), eDiv), a.type, a.type);

					case _:
						e;
				}
		}
	}
}
