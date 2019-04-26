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
				var eAttr = mkAttributeAccess(processExpr(x.eobj), x.name, x.syntax.at, x.syntax.dot, x.syntax.name, TTXMLList);
				var eZeroElem = mk(TEArrayAccess({
					syntax: {
						openBracket: mkOpenBracket(),
						closeBracket: new Token(0, TkBracketClose, "]", [], removeTrailingTrivia(eAttr))
					},
					eobj: eAttr,
					eindex: mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt)
				}), TTXMLList, TTXMLList);
				e.with(kind = TEBinop(eZeroElem, op, coerceToXML(eValue)));

			case TEXmlAttr(x):
				mkAttributeAccess(processExpr(x.eobj), x.name, x.syntax.at, x.syntax.dot, x.syntax.name, e.expectedType);

			case TEBinop({kind: TEXmlAttrExpr(x)}, op = OpAssign(_), eValue):
				eValue = processExpr(eValue);
				var eAttr = mkAttributeExprAccess(processExpr(x.eobj), processExpr(x.eattr), x.syntax.at, x.syntax.dot, x.syntax.openBracket, x.syntax.closeBracket, TTXMLList);
				var eZeroElem = mk(TEArrayAccess({
					syntax: {
						openBracket: mkOpenBracket(),
						closeBracket: new Token(0, TkBracketClose, "]", [], removeTrailingTrivia(eAttr))
					},
					eobj: eAttr,
					eindex: mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt)
				}), TTXMLList, TTXMLList);
				e.with(kind = TEBinop(eZeroElem, op, coerceToXML(eValue)));

			case TEXmlAttrExpr(x):
				mkAttributeExprAccess(processExpr(x.eobj), processExpr(x.eattr), x.syntax.at, x.syntax.dot, x.syntax.openBracket, x.syntax.closeBracket, e.expectedType);

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

			case TECall(eXml = {kind: TEBuiltin(syntax, "XML")}, args):
				var leadTrivia = syntax.leadTrivia;
				syntax.leadTrivia = [];
				var newKeyword = mkIdent("new", leadTrivia, [whitespace]);
				e.with(kind = TENew(newKeyword, eXml, args));

			case _:
				mapExpr(processExpr, e);
		}
	}

	static function coerceToXML(e:TExpr):TExpr {
		return switch e.type {
			case TTXML:
				e;
			case _:
				var newKeyword = mkIdent("new", removeTrailingTrivia(e), [whitespace]);
				mk(TENew(newKeyword, mkBuiltin("XML", TTBuiltin), {
					openParen: mkOpenParen(),
					args: [{expr: e, comma: null}],
					closeParen: new Token(0, TkParenClose, ")", [], removeTrailingTrivia(e))
				}), TTXML, TTXML);
		}
	}

	static function mkAttributeAccess(eobj:TExpr, name:String, at:Token, dot:Token, nameToken:Token, expectedType:TType):TExpr {
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
			expectedType
		);
	}

	static function mkAttributeExprAccess(eobj:TExpr, eattr:TExpr, at:Token, dot:Token, openBracket:Token, closeBracket:Token, expectedType:TType):TExpr {
		var fieldObject = {
			kind: TOExplicit(new Token(at.pos, TkDot, ".", at.leadTrivia, dot.trailTrivia), eobj),
			type: eobj.type
		};
		var eMethod = mk(TEField(fieldObject, "attribute", mkIdent("attribute")), tMethod, tMethod);
		return mk(
			TECall(eMethod, {
				openParen: new Token(openBracket.pos, TkParenOpen, "(", openBracket.leadTrivia, openBracket.trailTrivia),
				closeParen: new Token(closeBracket.pos, TkParenClose, ")", closeBracket.leadTrivia, closeBracket.trailTrivia),
				args: [{expr: eattr, comma: null}],
			}),
			TTXMLList,
			expectedType
		);
	}
}
