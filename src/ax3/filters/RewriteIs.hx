package ax3.filters;

class RewriteIs extends AbstractFilter {
	static final stdIs = mkBuiltin("Std.is", TTFun([TTAny, TTAny], TTBoolean));

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch (e.kind) {
			case TEBinop(a, OpIs(isToken), b):
				e.with(kind = TECall(stdIs, {
					openParen: mkOpenParen(),
					args: [
						{expr: a, comma: mkComma()},
						{expr: b, comma: null},
					],
					closeParen: mkCloseParen(),
				}));
			case _:
				e;
		}
	}
}
