package ax3.filters;

class RewriteNonBoolOr extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a, op = OpOr(_), b): // TODO not for TTBoolean
				var lead = removeLeadingTrivia(a);
				var tail = removeTrailingTrivia(b);

				var eChooseMethod = mkBuiltin("ASCompat.thisOrDefault", TTFunction, lead, []);

				mk(TECall(eChooseMethod, {
					openParen: mkOpenParen(),
					closeParen: new Token(0, TkParenClose, ")", [], tail),
					args: [
						{expr: a, comma: commaWithSpace},
						{expr: b, comma: null}
					],
				}), e.type, e.expectedType);

			case _:
				e;
		}
	}
}