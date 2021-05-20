package ax3.filters;

class RewriteNonBoolOr extends AbstractFilter {
	final coerceToBool:CoerceToBool;

	public function new(context, coerceToBool) {
		super(context);
		this.coerceToBool = coerceToBool;
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a, OpOr(_), b) if (a.type != TTBoolean || b.type != TTBoolean):

				if (canBeRepeated(a)) {
					mk(TEIf({
						syntax: {
							keyword: mkIdent("if", removeLeadingTrivia(a), [whitespace]),
							openParen: mkOpenParen(),
							closeParen: mkCloseParen(removeTrailingTrivia(a))
						},
						econd: coerceToBool.coerce(a),
						ethen: a,
						eelse: {
							keyword: mkIdent("else", [whitespace], [whitespace]),
							expr: b,
							semiliconBefore: false
						}
					}), e.type, e.expectedType);
				} else {
					var lead = removeLeadingTrivia(a);
					var tail = removeTrailingTrivia(b);

					var eChooseMethod = mkBuiltin("ASCompat.thisOrDefault", TTFunction, lead, []);

					mk(TECall(eChooseMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(tail),
						args: [
							{expr: a, comma: commaWithSpace},
							{expr: b, comma: null}
						],
					}), e.type, e.expectedType);
				}

			case _:
				e;
		}
	}
}