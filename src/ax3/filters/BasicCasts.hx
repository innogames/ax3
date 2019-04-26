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
			// int(expr)
			case TECast({syntax: syntax, expr: expr = {type: TTNumber}, type: TTInt | TTUint}):
				var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
				e.with(kind = TECall(stdInt, {
					openParen: syntax.openParen,
					args: [{expr: expr, comma: null}],
					closeParen: syntax.closeParen
				}));

			case TECast({syntax: syntax, expr: expr, type: TTInt | TTUint}):
				var eCastMethod = mkBuiltin("ASCompat.toInt", tToInt, removeLeadingTrivia(e));
				e.with(kind = TECall(eCastMethod, {
					openParen: syntax.openParen,
					args: [{expr: expr, comma: null}],
					closeParen: syntax.closeParen
				}));

			case TECast({syntax: syntax, expr: expr, type: TTNumber}):
				var eCastMethod = mkBuiltin("ASCompat.toNumber", tToNumber, removeLeadingTrivia(e));
				e.with(kind = TECall(eCastMethod, {
					openParen: syntax.openParen,
					args: [{expr: expr, comma: null}],
					closeParen: syntax.closeParen
				}));

			case TECast({syntax: syntax, expr: expr, type: TTBoolean}):
				// TODO: share some logic with CoerceToBool here
				var eCastMethod = mkBuiltin("ASCompat.toBool", tToBool, removeLeadingTrivia(e));
				e.with(kind = TECall(eCastMethod, {
					openParen: syntax.openParen,
					args: [{expr: expr, comma: null}],
					closeParen: syntax.closeParen
				}));

			case TECast({syntax: syntax, expr: expr, type: TTString}):
				var eCastMethod = mkBuiltin("ASCompat.toString", tToString, removeLeadingTrivia(e));
				e.with(kind = TECall(eCastMethod, {
					openParen: syntax.openParen,
					args: [{expr: expr, comma: null}],
					closeParen: syntax.closeParen
				}));

			case _:
				e;
		}
	}
}
