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
					case TECast({syntax: syntax, expr: expr = {type: TTNumber}, type: castedType = TTInt | TTUint}):
						var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
						e.with(kind = TECall(stdInt, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));

					case _:
						e;
				}
		}
	}
}
