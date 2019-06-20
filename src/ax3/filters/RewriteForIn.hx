package ax3.filters;

class RewriteForIn extends AbstractFilter {
	public static final tIteratorMethod = TTFun([], TTBuiltin);

	static inline function mkTempIterName() {
		return new Token(0, TkIdent, "_tmp_", [], [whitespace]);
	}

	override function processExpr(e:TExpr):TExpr {
		return switch (e.kind) {
			case TEForIn(f):
				var eobj = f.iter.eobj;
				var body = processExpr(f.body);

				var actualKeyType;
				switch eobj.type {
					case TTDictionary(keyType, _):
						actualKeyType = keyType;
						var obj = {
							kind: TOExplicit(mkDot(), eobj),
							type: eobj.type
						};
						var eKeys = mk(TEField(obj, "keys", mkIdent("keys")), tIteratorMethod, tIteratorMethod);
						eobj = mkCall(eKeys, []);

					case TTObject(_):
						actualKeyType = TTString;
						var obj = {
							kind: TOExplicit(mkDot(), eobj),
							type: eobj.type
						};
						var eKeys = mk(TEField(obj, "___keys", mkIdent("___keys")), tIteratorMethod, tIteratorMethod);
						eobj = mkCall(eKeys, []);

					case TTAny:
						actualKeyType = TTAny;
						var obj = {
							kind: TOExplicit(mkDot(), eobj),
							type: eobj.type
						};
						var eKeys = mk(TEField(obj, "___keys", mkIdent("___keys")), tIteratorMethod, tIteratorMethod);
						eobj = mkCall(eKeys, []);

					case TTXMLList:
						var obj = {
							kind: TOExplicit(mkDot(), eobj),
							type: eobj.type
						};
						var eKeys = mk(TEField(obj, "keys", mkIdent("keys")), tIteratorMethod, tIteratorMethod);
						eobj = mkCall(eKeys, []);
						actualKeyType = TTString;

					case TTArray(_) | TTVector(_):
						var pos = exprPos(eobj);
						var eZero = mk(TELiteral(TLInt(new Token(pos, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
						var eLength = {
							var obj = {
								kind: TOExplicit(mkDot(), eobj),
								type: eobj.type
							};
							mk(TEField(obj, "length", mkIdent("length")), TTInt, TTInt);
						};
						eobj = mk(TEHaxeIntIter(eZero, eLength), TTBuiltin, TTBuiltin);
						actualKeyType = TTInt;

					case _:
						actualKeyType = TTString;
				}


				var itName, vit;
				switch (f.iter.eit.kind) {
					// for (var x in obj)
					case TEVars(kind, [varDecl]):

						if (Type.enumEq(varDecl.v.type, actualKeyType)) {
							// easy - iterate over keys
							itName = varDecl.syntax.name;
							if (itName.trailTrivia.length == 0) {
								itName.trailTrivia.push(whitespace);
							}
							vit = varDecl.v;
						} else {
							// TODO: warn here?
							// harder - have to cast key to whatever type
							itName = mkTempIterName();
							vit = {name: itName.text, type: actualKeyType};

							var varInit = mk(TEVars(kind, [
								varDecl.with(init = {
									equalsToken: mkTokenWithSpaces(TkEquals, "="),
									expr: mk(TELocal(new Token(0, TkIdent, vit.name, [], []), vit), actualKeyType, varDecl.v.type)
								})
							]), TTVoid, TTVoid);

							body = concatExprs(varInit, body);
						}

					// for (x in obj)
					case TELocal(_, v):
						itName = mkTempIterName();
						vit = {name: itName.text, type: actualKeyType};

						var varInit = mk(TEBinop(
							f.iter.eit,
							OpAssign(mkTokenWithSpaces(TkEquals, "=")),
							mk(TELocal(new Token(0, TkIdent, vit.name, [], []), vit), actualKeyType, v.type)
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
