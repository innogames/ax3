package ax3.filters;

class NumberToInt extends AbstractFilter {
	public static final tStdInt = TTFun([TTNumber], TTInt);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch [e.type, e.expectedType] {
			case [TTNumber, TTInt | TTUint]:
				var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
				mkCall(stdInt, [e.with(expectedType = TTNumber)]);
			case _:
				e;
		}
	}
}
