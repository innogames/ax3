package ax3.filters;

class ToString extends AbstractFilter {
	public static final tToString = TTFun([], TTString);
	static final tStdString = TTFun([TTAny], TTString);
	static final tToRadix = TTFun([TTNumber], TTString);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: TTInt | TTUint | TTNumber | TTBoolean | TTAny | TTObject(_)})}, "toString", _)}, args = {args: []}):
				var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eStdString, args.with(args = [{expr: eValue, comma: null}])));

			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: TTInt | TTUint | TTNumber})}, "toString", _)}, args = {args: [digitsArg] }):
				var eToRadix = mkBuiltin("ASCompat.toRadix", tToRadix, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eToRadix, args.with(args = [{expr: eValue, comma: commaWithSpace}, digitsArg])));

			case _:
				// implicit to string coercions
				switch [e.type, e.expectedType] {
					case [TTString, TTString]:
						e; // ok

					case [TTAny | TTObject(_), TTString]:
						e; // handled at run-time

					case [TTInt | TTNumber, TTString]:
						var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(e));
						e.with(
							kind = TECall(eStdString, {
								openParen: mkOpenParen(),
								args: [{expr: e, comma: null}],
								closeParen: mkCloseParen(removeTrailingTrivia(e))
							}),
							type = TTString
						);

					case [TTXML | TTXMLList, TTString]:
						var eToString = mk(TEField({kind: TOExplicit(mkDot(), e), type: e.type}, "toString", mkIdent("toString")), tToString, tToString);
						mkCall(eToString, [], TTString, removeTrailingTrivia(e));

					// these are not really about "ToString", but I haven't found a better place to add them without introducing yet another filter
					// normally this can't happen in AS3, unless you do `for (var i:int in someObject)` then it can ¯\_(ツ)_/¯
					case [TTString, TTInt | TTUint]: mkCastCall("toInt", e, TTInt);
					case [TTString, TTNumber]: mkCastCall("toNumber", e, TTNumber);

					case [_, TTString]:
						reportError(exprPos(e), "Unknown to string coercion (actual type is " + e.type + ")");
						e;

					case _:
						e;
				}
		}
	}

	static function mkCastCall(methodName:String, e:TExpr, t:TType):TExpr {
		var eCastMethod = mkBuiltin("ASCompat." + methodName, TTFunction, removeLeadingTrivia(e));
		return e.with(
			kind = TECall(eCastMethod, {
				openParen: mkOpenParen(),
				args: [{expr: e, comma: null}],
				closeParen: mkCloseParen(removeTrailingTrivia(e))
			}),
			type = t
		);
	}
}