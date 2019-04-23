package ax3.filters;

class RewriteE4X extends AbstractFilter {
	static final tMethod = TTFun([TTAny], TTXMLList);

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEXmlChild(x):
				var eobj = processExpr(x.eobj);
				var fieldObject = {
					kind: TOExplicit(x.syntax.dot, eobj),
					type: eobj.type
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

			case TEBinop({kind: TEXmlAttr(x)}, op = OpAssign(_), eValue):
				eValue = processExpr(eValue);
				var eAttr = mkAttributeAccess(processExpr(x.eobj), x.name, x.syntax.at, x.syntax.dot, x.syntax.name);
				var eZeroElem = mk(TEArrayAccess({
					syntax: {
						openBracket: mkOpenBracket(),
						closeBracket: new Token(0, TkBracketClose, "]", [], removeTrailingTrivia(eAttr))
					},
					eobj: eAttr,
					eindex: mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt)
				}), TTXMLList, TTXMLList);
				e.with(kind = TEBinop(eZeroElem, op, eValue.with(expectedType = TTString)));

			case TEXmlAttr(x):
				var eobj = processExpr(x.eobj);
				mkAttributeAccess(eobj, x.name, x.syntax.at, x.syntax.dot, x.syntax.name);

			case TEXmlAttrExpr(x):
				var eobj = processExpr(x.eobj);
				var fieldObject = {
					kind: TOExplicit(new Token(x.syntax.at.pos, TkDot, ".", x.syntax.at.leadTrivia, x.syntax.dot.trailTrivia), eobj),
					type: eobj.type
				};
				var eMethod = mk(TEField(fieldObject, "attribute", mkIdent("attribute")), tMethod, tMethod);
				e.with(
					kind = TECall(eMethod, {
						openParen: new Token(x.syntax.openBracket.pos, TkParenOpen, "(", x.syntax.openBracket.leadTrivia, x.syntax.openBracket.trailTrivia),
						closeParen: new Token(x.syntax.closeBracket.pos, TkParenClose, ")", x.syntax.closeBracket.leadTrivia, x.syntax.closeBracket.trailTrivia),
						args: [{expr: processExpr(x.eattr), comma: null}],
					})
				);

			case TEXmlDescend(x):
				var eobj = processExpr(x.eobj);
				var fieldObject = {
					kind: TOExplicit(new Token(x.syntax.dotDot.pos, TkDot, ".", x.syntax.dotDot.leadTrivia, x.syntax.dotDot.trailTrivia), eobj),
					type: eobj.type
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
				mapExpr(processExpr, e);
		}
	}

	static function mkAttributeAccess(eobj:TExpr, name:String, at:Token, dot:Token, nameToken:Token):TExpr {
		var fieldObject = {
			kind: TOExplicit(new Token(at.pos, TkDot, ".", at.leadTrivia, dot.trailTrivia), eobj),
			type: eobj.type
		};
		var eMethod = mk(TEField(fieldObject, "attribute", mkIdent("attribute")), tMethod, tMethod);
		var descendantNameToken = new Token(0, TkStringDouble, haxe.Json.stringify(name), nameToken.leadTrivia, []);
		return mk(
			TECall(eMethod, {
				openParen: mkOpenParen(),
				closeParen: new Token(0, TkParenClose, ")", [], nameToken.trailTrivia),
				args: [{expr: mk(TELiteral(TLString(descendantNameToken)), TTString, TTString), comma: null}],
			}),
			TTXMLList,
			TTXMLList
		);
	}
}
