package ax3.filters;
/**
	Replace non-boolean values that are used where boolean is expected with a coercion call.
	E.g. `if (object)` to `if (object != null)`
**/
class CoerceToBool extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		if (e.expectedType == TTBoolean && e.type != TTBoolean) {
			return coerce(e);
		} else {
			return e;
		}
	}

	static function coerce(e:TExpr):TExpr {
		// TODO: add parens where needed
		return switch (e.type) {
			case TTBoolean:
				e; // shouldn't happen really

			case TTFunction | TTFun(_) | TTClass | TTObject | TTInst(_) | TTStatic(_) | TTArray | TTVector(_) | TTRegExp | TTXML | TTXMLList:
				var trail = removeTrailingTrivia(e);
				mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), mkNullExpr(e.type, [], trail)), TTBoolean, TTBoolean);

			case TTInt | TTUint:
				var trail = removeTrailingTrivia(e);
				var zeroExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], trail))), e.type, e.type);
				mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), zeroExpr), TTBoolean, TTBoolean);

			case TTString if (canBeRepeated(e)):
				var trail = removeTrailingTrivia(e);
				var nullExpr = mkNullExpr(TTString);
				var emptyExpr = mk(TELiteral(TLString(new Token(0, TkStringDouble, '""', [], trail))), TTString, TTString);
				var nullCheck = mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), nullExpr), TTBoolean, TTBoolean);
				var emptyCheck = mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), emptyExpr), TTBoolean, TTBoolean);
				mk(TEBinop(nullCheck, OpAnd(mkAndAndToken()), emptyCheck), TTBoolean, TTBoolean);

			case TTString | TTNumber | TTAny | TTVoid | TTBuiltin:
				// TODO
				// string: null or empty
				// number: Nan or 0
				// any: runtime helper + warning?
				// builtin: gotta remove this really
				// void: should NOT happen (cases like `v && v.f()` should be filtered before)
				// trace("(not) coercing " + e.type.getName());
				e;
		}
	}
}

