package ax3.filters;

import ax3.filters.NumberToInt.tStdInt;

class RewriteCasts extends AbstractFilter {
	static final tToBool = TTFun([TTAny], TTBoolean);
	static final tToInt = TTFun([TTAny], TTInt);
	static final tToNumber = TTFun([TTAny], TTNumber);
	static final tToString = TTFun([TTAny], TTString);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECast({syntax: syntax, expr: expr, type: castType}):

				inline function stripCast() {
					processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), expr);
					processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), expr);
					return expr.with(expectedType = e.expectedType); // it's important to keep the expected type for further filters
				}

				switch [expr.type, castType] {
					// int(number)
					case [TTNumber, TTInt | TTUint]:
						var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
						e.with(kind = TECall(stdInt, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));

					// int(already an int)
					case [TTInt | TTUint, TTInt | TTUint]:
						stripCast();

					// int(other)
					case [_, TTInt | TTUint]:
						expr = maybeCoerceToString(expr);
						var eCastMethod = mkBuiltin("ASCompat.toInt", tToInt, removeLeadingTrivia(e));
						e.with(kind = TECall(eCastMethod, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));

					// Number(already a number)
					case [TTNumber | TTInt | TTUint, TTNumber]:
						stripCast();

					// Number(other)
					case [_, TTNumber]:
						expr = maybeCoerceToString(expr);
						var eCastMethod = mkBuiltin("ASCompat.toNumber", tToNumber, removeLeadingTrivia(e));
						e.with(kind = TECall(eCastMethod, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));

					// Boolean(already a boolean)
					case [TTBoolean, TTBoolean]:
						stripCast();

					// Boolean(other)
					case [_, TTBoolean]:
						// TODO: share some logic with CoerceToBool here
						var eCastMethod = mkBuiltin("ASCompat.toBool", tToBool, removeLeadingTrivia(e));
						e.with(kind = TECall(eCastMethod, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));

					// String(already a string)
					case [TTString, TTString]:
						stripCast();

					// String(XML stuff)
					case [TTXML | TTXMLList, TTString]:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), expr);
						var eToString = mk(TEField({kind: TOExplicit(mkDot(), expr), type: expr.type}, "toString", mkIdent("toString")), ToString.tToString, ToString.tToString);
						e.with(kind = TECall(eToString, {openParen: syntax.openParen, args: [], closeParen: syntax.closeParen}), type = TTString);

					// String(other)
					case [_, TTString]:
						// maybe we can always just call Std.string for everything?
						var methodName = if (expr.type.match(TTInt | TTUint | TTNumber)) "Std.string" else "ASCompat.toString";
						var eCastMethod = mkBuiltin(methodName, tToString, removeLeadingTrivia(e));
						e.with(kind = TECall(eCastMethod, {
							openParen: syntax.openParen,
							args: [{expr: expr, comma: null}],
							closeParen: syntax.closeParen
						}));

					// Object(some) - I believe this is a noop
					case [_, TTObject(TTAny)]:
						stripCast();

					// SomeClass(value)
					case [exprType, TTInst(cls)]:
						switch determineCastKind(exprType, cls) {
							case CKSameClass | CKUpcast:
								stripCast();
							case CKDowncast | CKUnknown:
								e;
						}

					case _:
						throwError(exprPos(e), "TODO: unhandled cast variant");
				}

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
