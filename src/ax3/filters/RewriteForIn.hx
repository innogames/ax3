package ax3.filters;

class RewriteForIn extends AbstractFilter {
	static final tIteratorMethod = TTFun([], TTBuiltin);

	static inline function mkTempIterName() {
		return new Token(0, TkIdent, "_tmp_", [], [whitespace]);
	}

	override function processExpr(e:TExpr):TExpr {
		return switch (e.kind) {
			case TEForIn(f):
				var eobj = f.iter.eobj;
				var body = processExpr(f.body);

				// TODO: for...in on Dictionaries actually iterate over any keys

				switch eobj.type {
					case TTDictionary(_):
						var obj = {
							kind: TOExplicit(mkDot(), eobj),
							type: eobj.type
						};
						var eKeys = mk(TEField(obj, "keys", mkIdent("keys")), tIteratorMethod, tIteratorMethod);
						eobj = mkCall(eKeys, []);
					case _:
				}


				var itName, vit;
				switch (f.iter.eit.kind) {
					// for (var x in obj)
					case TEVars(kind, [varDecl]):

						if (varDecl.v.type == TTString) { // TODO: dictionary keys can be anything
							// easy - iterate over string keys
							itName = varDecl.syntax.name;
							if (itName.trailTrivia.length == 0) {
								itName.trailTrivia.push(whitespace);
							}
							vit = varDecl.v;
						} else {
							// harder - have to cast the string to whatever type
							itName = mkTempIterName();
							vit = {name: itName.text, type: TTString};

							var varInit = mk(TEVars(kind, [
								varDecl.with(init = {
									equalsToken: mkTokenWithSpaces(TkEquals, "="),
									expr: mk(TELocal(new Token(0, TkIdent, vit.name, [], []), vit), vit.type, varDecl.v.type)
								})
							]), TTVoid, TTVoid);

							body = concatExprs(varInit, body);
						}

					// for (x in obj)
					case TELocal(_, v):
						itName = mkTempIterName();
						vit = {name: itName.text, type: TTString};

						var varInit = mk(TEBinop(
							f.iter.eit,
							OpAssign(mkTokenWithSpaces(TkEquals, "=")),
							mk(TELocal(new Token(0, TkIdent, vit.name, [], []), vit), vit.type, v.type)
						), TTVoid, TTVoid);

						body = concatExprs(varInit, body);

					case _:
						throwError(exprPos(f.iter.eit), "Unsupported `for in` iterator");
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
						f.iter.eobj, // TODO: tempvar?
						OpEquals(mkEqualsEqualsToken()),
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
