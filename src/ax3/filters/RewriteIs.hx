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
						if (b.kind.match(TEVector(_))) {
							// TODO: figure out something "smart" for this, simiar to the pokemon catch in in `RewriteAs`,
							// because we can't just do `Std.is(expr, Vector)` - that won't work on Flash (because the Vector types are different)
							reportError(exprPos(e), "TODO: expr is Vector.<T> is not yet rewritten properly");
						}

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
