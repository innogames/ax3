package ax3.filters;

class RewriteAs extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEAs(eobj, keyword, typeRef):
				switch typeRef.type {
					case TTClass:
						e.with(kind = TEHaxeRetype(eobj));

					case TTInt | TTUint | TTNumber | TTString | TTBoolean: // omg
						reportError(keyword.pos, "`as` operator with basic type");
						e.with(kind = TECast({
							syntax: {
								openParen: mkOpenParen(),
								closeParen: mkCloseParen(),
								path: switch (typeRef.syntax) {
									case TPath(path): path;
									case _: throw "asset";
								}
							},
							expr: eobj,
							type: typeRef.type
						}));

					case TTVector(t):
						var eType = mkBuiltin("Vector", TTBuiltin);
						e.with(kind = makeStdInstance(eobj, eType, removeLeadingTrivia(e), removeTrailingTrivia(e)));

					case TTArray(_):
						var eType = mkBuiltin("Array", TTBuiltin);
						e.with(kind = makeStdInstance(eobj, eType, removeLeadingTrivia(e), removeTrailingTrivia(e)));

					case TTInst(cls):
						var path = switch (typeRef.syntax) {
							case TPath(path): path;
							case _: throw "asset";
						};
						var eType = mkDeclRef(path, {name: cls.name, kind: TDClassOrInterface(cls)}, null);
						e.with(kind = makeStdInstance(eobj, eType, removeLeadingTrivia(e), removeTrailingTrivia(e)));

					case _:
						throwError(keyword.pos, "Unsupported `as` expression");
				}
			case _:
				e;
		}
	}

	static function makeStdInstance(eObj:TExpr, eType:TExpr, leadTrivia, trailTrivia):TExprKind {
		var eMethod = mkBuiltin("ASCompat.as", TTFunction, leadTrivia);
		return TECall(eMethod, {
			openParen: mkOpenParen(),
			args: [
				{expr: eObj, comma: commaWithSpace},
				{expr: eType, comma: null},
			],
			closeParen: new Token(0, TkParenClose, ")", [], trailTrivia)
		});
	}
}
