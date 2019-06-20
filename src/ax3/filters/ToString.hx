package ax3.filters;

class ToString extends AbstractFilter {
	public static final tToString = TTFun([], TTString);
	static final tStdString = TTFun([TTAny], TTString);
	static final tHex = TTFun([TTInt], TTString);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: TTInt | TTUint | TTNumber | TTBoolean | TTAny | TTObject(_)})}, "toString", _)}, args = {args: []}):
				var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eStdString, args.with(args = [{expr: eValue, comma: null}])));

			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: TTInt | TTUint})}, "toString", fieldToken)}, args = {args: [{expr: {kind: TELiteral(TLInt({text: "16"}))}}]}):
				var eHex = mkBuiltin("StringTools.hex", tHex, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eHex, args.with(args = [{expr: eValue, comma: null}])));

			case _:
				// implicit to string coercions
				switch [e.type, e.expectedType] {
					case [TTString, TTString]:
						e; // ok

					case [TTAny, TTString]:
						e; // handled at run-time

					case [TTInt | TTNumber, TTString]:
						var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(e));
						e.with(kind = TECall(eStdString, {
							openParen: mkOpenParen(),
							args: [{expr: e, comma: null}],
							closeParen: new Token(0, TkParenClose, ")", [], removeTrailingTrivia(e))
						}));

					case [TTXML | TTXMLList, TTString]:
						var eToString = mk(TEField({kind: TOExplicit(mkDot(), e), type: e.type}, "toString", mkIdent("toString")), tToString, tToString);
						mkCall(eToString, [], TTString, removeTrailingTrivia(e));

					case [_, TTString]:
						reportError(exprPos(e), "Unknown to string coercion (actual type is " + e.type + ")");
						e;

					case _:
						e;
				}
		}
	}
}