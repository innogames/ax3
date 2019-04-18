package ax3.filters;

class NumberApi extends AbstractFilter {
	static final tToFixed = TTFun([TTNumber], TTString);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);

		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(_, eNumber = {type: TTNumber})}, "toFixed", _)}, args = {args: []}):
				var eMethod = mkBuiltin("ASCompat.toFixed", tToFixed, removeLeadingTrivia(eNumber));
				e.with(kind = TECall(eMethod, args.with(args = [{expr: eNumber, comma: null}])));

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "int")})}, "MAX_VALUE", fieldToken):
				return mkBuiltin("ASCompat.MAX_INT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "int")})}, "MIN_VALUE", fieldToken):
				return mkBuiltin("ASCompat.MIN_INT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "Number")})}, "MAX_VALUE", fieldToken):
				return mkBuiltin("ASCompat.MAX_FLOAT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "Number")})}, "MIN_VALUE", fieldToken):
				return mkBuiltin("ASCompat.MIN_FLOAT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case _:
				e;
		};
	}
}