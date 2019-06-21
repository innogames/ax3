package ax3.filters;

import ax3.filters.NumberToInt.tStdInt;

class BasicCasts extends AbstractFilter {
	static final tToBool = TTFun([TTAny], TTBoolean);
	static final tToInt = TTFun([TTAny], TTInt);
	static final tToNumber = TTFun([TTAny], TTNumber);
	static final tToString = TTFun([TTAny], TTString);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			// int(number)
			case TECast({syntax: syntax, expr: expr = {type: TTNumber}, type: TTInt | TTUint}):
				var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
				e.with(kind = TECall(stdInt, {
					openParen: syntax.openParen,
					args: [{expr: expr, comma: null}],
					closeParen: syntax.closeParen
				}));

			// int(other)
			case TECast({syntax: syntax, expr: expr, type: castType = TTInt | TTUint}):
				switch expr.type {
					// already an int
					case TTInt | TTUint:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), expr);
						processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), expr);
						expr;

					// something different
					case _:
						expr = maybeCoerceToString(expr);
						var eCastMethod = mkBuiltin("ASCompat.toInt", tToInt, removeLeadingTrivia(e));
						e.with(kind = TECall(eCastMethod, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));
				}

			// Number(some)
			case TECast({syntax: syntax, expr: expr, type: TTNumber}):
				switch expr.type {
					// already a number
					case TTNumber | TTInt | TTUint: // TODO: is it really safe to include Int types here?
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), expr);
						processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), expr);
						expr;

					// something different
					case _:
						expr = maybeCoerceToString(expr);
						var eCastMethod = mkBuiltin("ASCompat.toNumber", tToNumber, removeLeadingTrivia(e));
						e.with(kind = TECall(eCastMethod, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));
				}

			// Boolean(some)
			case TECast({syntax: syntax, expr: expr, type: TTBoolean}):
				switch expr.type {
					// already a boolean
					case TTBoolean:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), expr);
						processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), expr);
						expr;

					// something different
					case _:
						// TODO: share some logic with CoerceToBool here
						var eCastMethod = mkBuiltin("ASCompat.toBool", tToBool, removeLeadingTrivia(e));
						e.with(kind = TECall(eCastMethod, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));
				}

			// String(some)
			case TECast({syntax: syntax, expr: expr, type: TTString}):
				switch expr.type {
					// already a string
					case TTString:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), expr);
						processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), expr);
						expr;

					// XML stuff
					case TTXML | TTXMLList:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), expr);
						var eToString = mk(TEField({kind: TOExplicit(mkDot(), expr), type: expr.type}, "toString", mkIdent("toString")), ToString.tToString, ToString.tToString);
						e.with(kind = TECall(eToString, {openParen: syntax.openParen, args: [], closeParen: syntax.closeParen}), type = TTString);

					// something different
					case _:
						var eCastMethod = mkBuiltin("ASCompat.toString", tToString, removeLeadingTrivia(e));
						e.with(kind = TECall(eCastMethod, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));
				}

			// Object(some) - I believe this is a noop
			case TECast({expr: expr, type: TTObject(TTAny)}):
				processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), expr);
				processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), expr);
				expr;

			case _:
				e;
		}
	}

	static function maybeCoerceToString(e:TExpr):TExpr {
		if (e.type.match(TTXML | TTXMLList)) {
			return e.with(expectedType = TTString); // this will be handled by a ToString filter
		} else {
			return e;
		}
	}
}
