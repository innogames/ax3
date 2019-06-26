package ax3.filters;

class RewriteAs extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEAs(eobj, keyword, typeRef):
				switch typeRef.type {
					case TTClass | TTFunction:
						e.with(kind = TEHaxeRetype(eobj));

					case TTObject(tElem):
						if (tElem != TTAny) throwError(exprPos(e), "assert"); // only TTObject(TTAny) can come from AS3 `as` cast
						e.with(kind = TEHaxeRetype(eobj));

					case TTInt | TTUint | TTNumber | TTString | TTBoolean: // omg
						// TODO: this is not correct: we need to actually check and return null here
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

					case TTArray(tElem):
						if (tElem != TTAny) throwError(exprPos(e), "assert"); // only TTArray(TTAny) can come from AS3 `as` cast
						var needsTypeCheck = false;
						var type = switch e.expectedType {
							case TTArray(_): needsTypeCheck = true; e.expectedType;
							case _: tUntypedArray;
						};
						var e = mk(makeAs(eobj, mkBuiltin("Array", TTBuiltin), removeLeadingTrivia(e), removeTrailingTrivia(e)), type, e.expectedType);
						e.with(kind = TEHaxeRetype(e));

					case TTInst(cls):
						var path = switch (typeRef.syntax) {
							case TPath(path): path;
							case _: throw "asset";
						};
						var eType = mkDeclRef(path, {name: cls.name, kind: TDClassOrInterface(cls)}, null);

						// TODO: apply the same logic to casts?
						switch determineCastKind(eobj.type, cls) {
							case CKSameClass:
								processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), eobj);
								eobj;
							case CKUpcast:
								processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), eobj);
								// TODO: review this, maybe CKSameClass and CKUpcast must be merged and the `as` should be eliminated
								switch e.expectedType {
									case TTVoid:
										eobj;
									case TTInst(expectedClass) if (expectedClass == cls):
										// TODO: also allow upcasting here (I really need a generic unification check function)
										eobj;
									case _:
										e.with(kind = TEHaxeRetype(eobj));
								}
							case CKDowncast:
								e.with(kind = makeStdDowncast(eobj, eType, removeLeadingTrivia(e), removeTrailingTrivia(e)));
							case CKUnknown:
								e.with(kind = makeAs(eobj, eType, removeLeadingTrivia(e), removeTrailingTrivia(e)));
						}

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

	static function makeStdDowncast(eObj:TExpr, eType:TExpr, leadTrivia, trailTrivia):TExprKind {
		var eMethod = mkBuiltin("Std.downcast", TTFunction, leadTrivia);
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
