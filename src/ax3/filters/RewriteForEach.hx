package ax3.filters;

class RewriteForEach extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch (e.kind) {
			case TEForEach(f):
				var eobj = f.iter.eobj;
				var body = processExpr(f.body);

				switch eobj.type {
					case TTArray(_) | TTVector(_) | TTDictionary(_) | TTObject(_) | TTAny:
					case TTXMLList: // TODO: rewrite this
					case _:
						throwError(exprPos(eobj), "Unknown `for each` iteratee");
				}

				var itName, vit;
				switch (f.iter.eit.kind) {
					// for each (var x in obj) - use the var directly
					case TEVars(_, [varDecl]):
						itName = addTrailingWhitespace(varDecl.syntax.name);
						vit = varDecl.v;

					// for each (x in obj) - use tempvar and assign to var, because it might be used outside
					case TELocal(token, v):
						var tmpName = "_tmp_";
						itName = mkIdent(tmpName, [], [whitespace]);
						vit = {name: tmpName, type: v.type};
						var eAssign = mk(TEBinop(
							f.iter.eit,
							OpAssign(new Token(0, TkEquals, "=", [whitespace], [whitespace])),
							mk(TELocal(mkIdent(tmpName), vit), v.type, v.type)
						), v.type, v.type);
						body = concatExprs(eAssign, body);

					case _:
						throwError(exprPos(f.iter.eit), "Unsupported `for each in` iterator");
				}

				var eFor = mk(TEHaxeFor({
					syntax: {
						forKeyword: f.syntax.forKeyword,
						openParen: f.syntax.openParen,
						itName: itName,
						inKeyword: f.iter.inKeyword,
						closeParen: f.syntax.closeParen
					},
					vit: vit,
					iter: eobj,
					body: body
				}), TTVoid, TTVoid);

				mk(TEIf({
					syntax: {
						keyword: mkIdent("if", removeLeadingTrivia(eFor), [whitespace]),
						openParen: mkOpenParen(),
						closeParen: addTrailingWhitespace(mkCloseParen()),
					},
					econd: mk(TEBinop(
						eobj, // TODO: tempvar?
						OpNotEquals(mkNotEqualsToken()),
						mkNullExpr()
					), TTBoolean, TTBoolean),
					ethen: eFor,
					eelse: null
				}), TTVoid, TTVoid);

			case _:
				mapExpr(processExpr, e);
		}
	}
}
