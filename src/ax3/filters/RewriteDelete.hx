package ax3.filters;

class RewriteDelete extends AbstractFilter {
	static final tDeleteField = TTFun([TTAny, TTString], TTBoolean);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch (e.kind) {
			case TEDelete(keyword, eobj):
				switch eobj.kind {
					case TEArrayAccess(a) | TEParens(_, {kind: TEArrayAccess(a)}, _):
						rewrite(keyword, a, eobj, e);

					case _:
						reportError(exprPos(eobj), "Unsupported `delete` operation");
						e;
				}
			case _:
				e;
		}
	}

	function rewrite(deleteKeyword:Token, a:TArrayAccess, eDeleteObj:TExpr, eDelete:TExpr):TExpr {
		// TODO: trivia \o/
		return switch [a.eobj.type, a.eindex.type] {
			case [TTDictionary(keyType, _), _]:
				processLeadingToken(function(t) {
					t.leadTrivia = deleteKeyword.leadTrivia.concat(t.leadTrivia);
				}, a.eobj);

				var eRemoveField = mk(TEField({kind: TOExplicit(mkDot(), a.eobj), type: a.eobj.type}, "remove", mkIdent("remove")), TTFunction, TTFunction);
				mkCall(eRemoveField, [a.eindex.with(expectedType = keyType)], TTBoolean);

			case [TTObject(_) | TTAny, _] | [_, TTString]:
				// TODO: this should actually generate (expr : ASObject).___delete that handles delection of Dictionary keys too
				// make sure the expected type is string so further filters add the cast
				var eindex = if (a.eindex.type != TTString) a.eindex.with(expectedType = TTString) else a.eindex;
				var eDeleteField = mkBuiltin("Reflect.deleteField", tDeleteField, deleteKeyword.leadTrivia);
				eDelete.with(kind = TECall(eDeleteField, {
					openParen: new Token(0, TkParenOpen, "(", a.syntax.openBracket.leadTrivia, a.syntax.openBracket.trailTrivia),
					closeParen: new Token(0, TkParenClose, ")", a.syntax.openBracket.leadTrivia, a.syntax.openBracket.trailTrivia),
					args: [{expr: a.eobj, comma: commaWithSpace}, {expr: eindex, comma: null}]
				}));

			case [TTXMLList, TTInt | TTUint]:
				reportError(deleteKeyword.pos, 'TODO: delete on XMLList');
				mkNullExpr(eDelete.expectedType);

			case [TTArray(_), TTInt | TTUint]:
				reportError(exprPos(a.eindex), 'delete on array?');

				if (eDelete.expectedType == TTBoolean) {
					throw "TODO"; // always true probably
				}

				processLeadingToken(function(t) {
					t.leadTrivia = deleteKeyword.leadTrivia.concat(t.leadTrivia);
				}, eDeleteObj);

				mk(TEBinop(eDeleteObj, OpAssign(new Token(0, TkEquals, "=", [], [])), mkNullExpr()), TTVoid, TTVoid);

			case _:
				throwError(exprPos(a.eindex), 'Unknown `delete` expression: index type = ${a.eindex.type.getName()}, object type = ${a.eobj.type}');
		}
	}
}