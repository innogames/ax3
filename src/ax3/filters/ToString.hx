package ax3.filters;

class ToString extends AbstractFilter {
	static final tStdString = TTFun([TTAny], TTString);
	static final tHex = TTFun([TTInt], TTString);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: TTInt | TTUint | TTNumber | TTBoolean})}, "toString", fieldToken)}, args = {args: []}):
				var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eStdString, args.with(args = [{expr: eValue, comma: null}])));

			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: TTInt | TTUint})}, "toString", fieldToken)}, args = {args: [{expr: {kind: TELiteral(TLInt({text: "16"}))}}]}):
				var eHex = mkBuiltin("StringTools.hex", tHex, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eHex, args.with(args = [{expr: eValue, comma: null}])));

			case _:
				e;
		}
	}
}