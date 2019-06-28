package ax3.filters;

class RewriteIs extends AbstractFilter {
	static final tStdIs = TTFun([TTAny, TTAny], TTBoolean);
	static final tIsFunction = TTFun([TTAny], TTBoolean);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a, OpIs(_), b):
				switch b.kind {
					case TEBuiltin(_, "Function"):
						final isFunction = mkBuiltin("Reflect.isFunction", tIsFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(isFunction, {
							openParen: mkOpenParen(),
							args: [{expr: a, comma: null}],
							closeParen: mkCloseParen(removeTrailingTrivia(e)),
						}));

					case _:
						final stdIs = mkBuiltin("Std.is", tStdIs, removeLeadingTrivia(e));
						e.with(kind = TECall(stdIs, {
							openParen: mkOpenParen(),
							args: [
								{expr: a, comma: commaWithSpace},
								{expr: b, comma: null},
							],
							closeParen: mkCloseParen(removeTrailingTrivia(e)),
						}));
				}
			case _:
				e;
		}
	}
}
