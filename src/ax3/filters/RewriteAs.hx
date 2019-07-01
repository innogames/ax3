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

					case TTVector(elemType):
						var eAsVectorMethod = mkBuiltin("ASCompat.asVector", TTFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(eAsVectorMethod, {
							openParen: mkOpenParen(),
							args: [
								{expr: eobj, comma: commaWithSpace},
								{expr: mkVectorTypeCheckMacroArg(elemType), comma: null}
							],
							closeParen: mkCloseParen(removeTrailingTrivia(e))
						}));

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

						switch determineCastKind(eobj.type, cls) {
							case CKSameClass | CKUpcast:
								processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), eobj);
								eobj.with(expectedType = e.expectedType); // it's important to keep the expected type for further filters
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

	static final eUnderscore = mkBuiltin("_", TTBuiltin);

	public static function mkVectorTypeCheckMacroArg(elemType:TType):TExpr {
		return mk(TEHaxeRetype(eUnderscore), elemType, elemType);
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
