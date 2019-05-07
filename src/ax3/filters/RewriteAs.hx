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
						// generate `try (<expr> : Vector<Type>) catch (pokemon:Any) null`
						// beause that's the only way to mimic `expr as Vector<Type>` with Haxe

						// TODO: ideally we should retype the whole try/catch, but it doesn't currently work,
						// because of https://github.com/HaxeFoundation/haxe/issues/8257
						mk(TETry({
							keyword: mkIdent("try", removeLeadingTrivia(e), [whitespace]),
							expr: eobj.with(kind = TEHaxeRetype(eobj), type = typeRef.type),
							catches: [{
								syntax: {
									keyword: mkIdent("catch", [], [whitespace]),
									openParen: mkOpenParen(),
									name: mkIdent("pokemon"),
									type: {
										colon: new Token(0, TkColon, ":", [], []),
										type: TAny(new Token(0, TkAsterisk, "*", [], []))
									},
									closeParen: addTrailingWhitespace(mkCloseParen())
								},
								v:{name: "pokemon", type: TTAny},
								expr: mkNullExpr(typeRef.type, [], removeTrailingTrivia(e))
							}]
						}), typeRef.type, e.expectedType);

					case TTArray(_):
						var eType = mkBuiltin("Array", TTBuiltin);
						e.with(kind = makeAs(eobj, eType, removeLeadingTrivia(e), removeTrailingTrivia(e)));

					case TTInst(cls):
						var path = switch (typeRef.syntax) {
							case TPath(path): path;
							case _: throw "asset";
						};
						var eType = mkDeclRef(path, {name: cls.name, kind: TDClassOrInterface(cls)}, null);
						e.with(kind = makeAs(eobj, eType, removeLeadingTrivia(e), removeTrailingTrivia(e)));

					case _:
						throwError(keyword.pos, "Unsupported `as` expression");
				}
			case _:
				e;
		}
	}

	static function makeAs(eObj:TExpr, eType:TExpr, leadTrivia, trailTrivia):TExprKind {
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
