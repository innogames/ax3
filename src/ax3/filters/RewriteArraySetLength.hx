package ax3.filters;

class RewriteArraySetLength extends AbstractFilter {
	static final tResize = TTFun([TTInt], TTVoid);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch (e.kind) {
			case TEBinop({kind: TEField(to = {kind: TOExplicit(dot, eArray), type: TTArray(_)}, "length", _)}, op = OpAssign(_), eNewLength):
				if (e.expectedType == TTVoid) {
					// block-level length assignment - safe to just call Haxe's "resize" method
					e.with(
						kind = TECall(
							mk(TEField(to, "resize", mkIdent("resize")), tResize, tResize),
							{
								openParen: mkOpenParen(),
								closeParen: mkCloseParen(),
								args: [{expr: eNewLength, comma: null}]
							}
						)
					);
				} else {
					// possibly value-level length assignment - need to call compat method
					var eCompatMethod = mkBuiltin("ASCompat.arraySetLength", TTFunction, removeLeadingTrivia(eArray), []);
					e.with(kind = TECall(eCompatMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(),
						args: [
							{expr: eArray, comma: mkCommaWithSpace()},
							{expr: eNewLength, comma: null}
						]
					}));
				}
			case _:
				e;
		}
	}
}
