package ax3.filters;

class RewriteForIn extends AbstractFilter {
	static inline function mkTempIterName() {
		return new Token(0, TkIdent, "__tmp", [], [mkWhitespace()]);
	}

	override function processExpr(e:TExpr):TExpr {
		return switch (e.kind) {
			case TEForIn(f):
				var body = processExpr(f.body);

				var itName, vit, eobj;
				switch (f.iter.eit.kind) {
					// for (var x in obj)
					case TEVars(kind, [varDecl]):

						if (varDecl.v.type == TTString) {
							// easy - iterate over string keys
							itName = varDecl.syntax.name;
							if (itName.trailTrivia.length == 0) {
								itName.trailTrivia.push(mkWhitespace());
							}
							vit = varDecl.v;
						} else {
							// harder - have to cast the string to whatever type
							itName = mkTempIterName();
							vit = {name: itName.text, type: TTString};

							var varInit = mk(TEVars(kind, [
								varDecl.with(init = {
									equals: mkTokenWithSpaces(TkEquals, "="),
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
						reportError(exprPos(f.iter.eit), "Unsupported `for in` iterator");
						throw "assert";
				};

				var eobj = f.iter.eobj;

				mk(TEHaxeFor({
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

			case _:
				mapExpr(processExpr, e);
		}
	}
}
