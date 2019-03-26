package ax3.filters;

class NumberToInt extends AbstractFilter {
	static final tStdInt = TTFun([TTNumber], TTInt);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch [e.type, e.expectedType] {
			case [TTNumber, TTInt | TTUint]:
				var stdInt = mkBuiltin("Std.int", tStdInt);
				var call = mkCall(stdInt, [e]);
				processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e), call);
				processTrailingToken(t -> t.trailTrivia = removeTrailingTrivia(e), call);
				call;

			case _:
				e;
		}
	}
}
