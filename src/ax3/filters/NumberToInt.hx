package ax3.filters;

class NumberToInt extends AbstractFilter {
	static final stdInt = {
		var t = TTFun([TTNumber], TTInt);
		mk(TEBuiltin(mkIdent("Std.int"), "Std.int"), t, t);
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch [e.type, e.expectedType] {
			case [TTNumber, TTInt | TTUint]:
				mkCall(stdInt, [e]);
			case _:
				e;
		}
	}
}
