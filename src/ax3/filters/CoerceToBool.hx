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

	static final tStringAsBool = TTFun([TTString], TTBoolean);
	static final tFloatAsBool = TTFun([TTNumber], TTBoolean);
	static final tIntAsBool = TTFun([TTInt], TTBoolean);

	public function coerce(e:TExpr):TExpr {
		if (e.kind.match(TEBinop(_, OpAnd(_) | OpOr(_), _))) {
			// inner expressions are already coerced, so we just need to fix the type for the binop
			return e.with(type = TTBoolean);
		}

		return switch (e.type) {
			case TTBoolean:
				e; // shouldn't happen really

			case TTFunction | TTFun(_) | TTClass | TTInst(_) | TTStatic(_) | TTArray(_) | TTVector(_) | TTRegExp | TTXML | TTXMLList | TTDictionary(_, _):
				var trail = removeTrailingTrivia(e);
				mk(TEBinop(e.with(expectedType = e.type), OpNotEquals(mkNotEqualsToken()), mkNullExpr(e.type, [], trail)), TTBoolean, TTBoolean);

			case TTInt | TTUint:
				if (isNullable(e)) {
					var lead = removeLeadingTrivia(e);
					var tail = removeTrailingTrivia(e);
					var eIntAsBoolMethod = mkBuiltin("ASCompat.intAsBool", tIntAsBool, lead, []);
					mk(TECall(eIntAsBoolMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(tail),
						args: [{expr: e.with(expectedType = e.type), comma: null}],
					}), TTBoolean, TTBoolean);
				} else {
					var trail = removeTrailingTrivia(e);
					var zeroExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], trail))), e.type, e.type);
					mk(TEBinop(e.with(expectedType = e.type), OpNotEquals(mkNotEqualsToken()), zeroExpr), TTBoolean, TTBoolean);
				}

			// case TTString if (canBeRepeated(e)):
			// 	var trail = removeTrailingTrivia(e);
			// 	var nullExpr = mkNullExpr(TTString);
			// 	var emptyExpr = mk(TELiteral(TLString(new Token(0, TkStringDouble, '""', [], trail))), TTString, TTString);
			// 	var nullCheck = mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), nullExpr), TTBoolean, TTBoolean);
			// 	var emptyCheck = mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), emptyExpr), TTBoolean, TTBoolean);
			// 	mk(TEBinop(nullCheck, OpAnd(mkAndAndToken()), emptyCheck), TTBoolean, TTBoolean);

			case TTString:
				var lead = removeLeadingTrivia(e);
				var tail = removeTrailingTrivia(e);
				var eStringAsBoolMethod = mkBuiltin("ASCompat.stringAsBool", tStringAsBool, lead, []);
				mk(TECall(eStringAsBoolMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(tail),
					args: [{expr: e.with(expectedType = e.type), comma: null}],
				}), TTBoolean, TTBoolean);

			case TTNumber:
				var lead = removeLeadingTrivia(e);
				var tail = removeTrailingTrivia(e);
				var eFloatAsBoolMethod = mkBuiltin("ASCompat.floatAsBool", tFloatAsBool, lead, []);
				mk(TECall(eFloatAsBoolMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(tail),
					args: [{expr: e.with(expectedType = e.type), comma: null}],
				}), TTBoolean, TTBoolean);

			case TTAny | TTObject(_):
				e.with(expectedType = e.type); // handled at run-time by the ASAny/ASObject abstract \o/

			case TTVoid:
				throwError(exprPos(e), "void used as Bool?");

			case TTBuiltin:
				throwError(exprPos(e), "TODO: bool coecion");
		}
	}

	static function isNullable(e:TExpr):Bool {
		// TODO: this should really be done properly using TTNull(t) instead of relying on specific expressions
		return switch skipParens(e).kind {
			case TEArrayAccess({eobj: {type: TTDictionary(_, _)}}): true;
			case _: false;
		}
	}
}
