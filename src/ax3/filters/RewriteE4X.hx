package ax3.filters;

class RewriteE4X extends AbstractFilter {
	static final tMethod = TTFun([TTAny], TTXMLList);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEXmlChild(x):
				var fieldObject = {
					kind: TOExplicit(x.syntax.dot, x.eobj),
					type: x.eobj.type
				};
				var eMethod = mk(TEField(fieldObject, "child", mkIdent("child")), tMethod, tMethod);
				var descendantNameToken = new Token(0, TkStringDouble, haxe.Json.stringify(x.name), x.syntax.name.leadTrivia, x.syntax.name.trailTrivia);
				e.with(
					kind = TECall(eMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(),
						args: [{expr: mk(TELiteral(TLString(descendantNameToken)), TTString, TTString), comma: null}],
					})
				);

			case TEXmlAttr(x):
				var fieldObject = {
					kind: TOExplicit(new Token(x.syntax.at.pos, TkDot, ".", x.syntax.at.leadTrivia, x.syntax.dot.trailTrivia), x.eobj),
					type: x.eobj.type
				};
				var eMethod = mk(TEField(fieldObject, "attribute", mkIdent("attribute")), tMethod, tMethod);
				var descendantNameToken = new Token(0, TkStringDouble, haxe.Json.stringify(x.name), x.syntax.name.leadTrivia, x.syntax.name.trailTrivia);
				e.with(
					kind = TECall(eMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(),
						args: [{expr: mk(TELiteral(TLString(descendantNameToken)), TTString, TTString), comma: null}],
					})
				);

			case TEXmlAttrExpr(x):
				var fieldObject = {
					kind: TOExplicit(new Token(x.syntax.at.pos, TkDot, ".", x.syntax.at.leadTrivia, x.syntax.dot.trailTrivia), x.eobj),
					type: x.eobj.type
				};
				var eMethod = mk(TEField(fieldObject, "attribute", mkIdent("attribute")), tMethod, tMethod);
				e.with(
					kind = TECall(eMethod, {
						openParen: new Token(x.syntax.openBracket.pos, TkParenOpen, "(", x.syntax.openBracket.leadTrivia, x.syntax.openBracket.trailTrivia),
						closeParen: new Token(x.syntax.closeBracket.pos, TkParenClose, ")", x.syntax.closeBracket.leadTrivia, x.syntax.closeBracket.trailTrivia),
						args: [{expr: x.eattr, comma: null}],
					})
				);

			case TEXmlDescend(x):
				var fieldObject = {
					kind: TOExplicit(new Token(x.syntax.dotDot.pos, TkDot, ".", x.syntax.dotDot.leadTrivia, x.syntax.dotDot.trailTrivia), x.eobj),
					type: x.eobj.type
				};
				var eMethod = mk(TEField(fieldObject, "descendants", mkIdent("descendants")), tMethod, tMethod);
				var descendantNameToken = new Token(0, TkStringDouble, haxe.Json.stringify(x.name), x.syntax.name.leadTrivia, x.syntax.name.trailTrivia);
				e.with(
					kind = TECall(eMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(),
						args: [{expr: mk(TELiteral(TLString(descendantNameToken)), TTString, TTString), comma: null}],
					})
				);

			case _:
				e;
		}
	}
}
