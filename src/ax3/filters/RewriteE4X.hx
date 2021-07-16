package ax3.filters;

class RewriteE4X extends AbstractFilter {
	static final tMethod = TTFun([TTAny], TTXMLList);
	static final tSetAttribute = TTFun([TTString, TTString], TTString);

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEXmlChild(x) if (x.name == "appendChild" || x.name == "children"):
				var eobj = processExpr(x.eobj);
				assertIsXML(eobj);
				var fieldObject = {
					kind: TOExplicit(x.syntax.dot, eobj),
					type: eobj.type
				};
				return mk(TEField(fieldObject, x.name, mkIdent(x.name)), tMethod, tMethod);
			case TEXmlChild(x):
				var eobj = processExpr(x.eobj);
				assertIsXML(eobj);
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

			case TEBinop({kind: TEXmlAttr(x)}, OpAssign(_), eValue):
				eValue = processExpr(eValue);
				var eobj = processExpr(x.eobj);
				assertIsXML(eobj);

				var fieldObject = {
					kind: TOExplicit(new Token(x.syntax.at.pos, TkDot, ".", x.syntax.at.leadTrivia, x.syntax.dot.trailTrivia), eobj),
					type: eobj.type
				};

				var eMethod = mk(TEField(fieldObject, "setAttribute", mkIdent("setAttribute")), tSetAttribute, tSetAttribute);
				var attrNameToken = new Token(0, TkStringDouble, haxe.Json.stringify(x.name), x.syntax.name.leadTrivia, []);

				return mk(
					TECall(eMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(x.syntax.name.trailTrivia),
						args: [
							{expr: mk(TELiteral(TLString(attrNameToken)), TTString, TTString), comma: commaWithSpace},
							{expr: eValue.with(expectedType = TTString), comma: null}
						],
					}),
					TTString,
					e.expectedType
				);

			case TEXmlAttr(x):
				var eobj = processExpr(x.eobj);
				assertIsXML(eobj);
				mkAttributeAccess(eobj, x.name, x.syntax.at, x.syntax.dot, x.syntax.name, e.expectedType);

			case TEBinop({kind: TEXmlAttrExpr(x)}, OpAssign(_), eValue):
				eValue = processExpr(eValue);

				var eobj = processExpr(x.eobj);
				assertIsXML(eobj);
				var eattr = processExpr(x.eattr);

				var fieldObject = {
					kind: TOExplicit(new Token(x.syntax.at.pos, TkDot, ".", x.syntax.at.leadTrivia, x.syntax.dot.trailTrivia), eobj),
					type: eobj.type
				};
				var eMethod = mk(TEField(fieldObject, "setAttribute", mkIdent("setAttribute")), tSetAttribute, tSetAttribute);

				return mk(
					TECall(eMethod, {
						openParen: new Token(x.syntax.openBracket.pos, TkParenOpen, "(", x.syntax.openBracket.leadTrivia, x.syntax.openBracket.trailTrivia),
						closeParen: new Token(x.syntax.closeBracket.pos, TkParenClose, ")", x.syntax.closeBracket.leadTrivia, x.syntax.closeBracket.trailTrivia),
						args: [
							{expr: eattr, comma: commaWithSpace},
							{expr: eValue.with(expectedType = TTString), comma: null}
						],
					}),
					TTString,
					e.expectedType
				);

			case TEXmlAttrExpr(x):
				var eobj = processExpr(x.eobj);
				assertIsXML(eobj);
				mkAttributeExprAccess(eobj, processExpr(x.eattr), x.syntax.at, x.syntax.dot, x.syntax.openBracket, x.syntax.closeBracket, e.expectedType);

			case TEXmlDescend(x):
				var eobj = processExpr(x.eobj);
				assertIsXML(eobj);
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

			case TECall({kind: TEBuiltin(syntax, "XML")}, args):
				var leadTrivia = syntax.leadTrivia;
				syntax.leadTrivia = [];
				var newKeyword = mkIdent("new", leadTrivia, [whitespace]);
				var xmlNewObject = TNType({syntax: TPath({first: syntax, rest: []}), type: TTXML});
				e.with(kind = TENew(newKeyword, xmlNewObject, args));

			case _:
				mapExpr(processExpr, e);
		}
	}

	function assertIsXML(e:TExpr) {
		if (!e.type.match(TTXML | TTXMLList)) {
			throwError(exprPos(e), 'E4X syntax is used on non-XML expression (type: ${e.type})');
		}
	}

	static function coerceToXML(e:TExpr):TExpr {
		return switch e.type {
			case TTXML:
				e;
			case _:
				var newKeyword = mkIdent("new", removeTrailingTrivia(e), [whitespace]);
				var xmlNewObject = TNType({syntax: TPath({first: mkIdent("XML"), rest: []}), type: TTXML});
				mk(TENew(newKeyword, xmlNewObject, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(removeTrailingTrivia(e)),
					args: [{expr: e, comma: null}]
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
				closeParen: mkCloseParen(nameToken.trailTrivia),
				args: [{expr: mk(TELiteral(TLString(descendantNameToken)), TTString, TTString), comma: null}],
			}),
			TTString,
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
			TTString,
			expectedType
		);
	}
}
