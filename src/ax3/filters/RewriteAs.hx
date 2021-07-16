package ax3.filters;

class RewriteAs extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEAs(eobj, keyword, typeRef):
				switch typeRef.type {
					case TTClass:
						// just strip out `as`, I don't think we can really downcast to `Class` in Haxe
						switch e.expectedType {
							case TTClass | TTStatic(_):
								// if the expected type is Class or even Class<T> - just remove `as`
								processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), eobj);
								eobj.with(expectedType = e.expectedType);
							case _:
								// otherwise wrap in type-check, to have the same type checking as when expected type is Class
								e.with(kind = TEHaxeRetype(eobj));
						};

					case TTObject(tElem):
						if (tElem != TTAny) throwError(exprPos(e), "assert"); // only TTObject(TTAny) can come from AS3 `as` cast
						e.with(kind = TEHaxeRetype(eobj));

					case TTFunction:
						var eAsFunctionMethod = mkBuiltin("ASCompat.asFunction", TTFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(eAsFunctionMethod, {
							openParen: mkOpenParen(),
							args: [{expr: eobj, comma: null}],
							closeParen: mkCloseParen(removeTrailingTrivia(e))
						}));

					case TTInt | TTUint | TTNumber | TTString | TTBoolean: // omg
						// TODO: this is not correct: we need to actually check and return null here
						reportError(keyword.pos, "`as` operator with basic type");

						var path, trail;
						switch (typeRef.syntax) {
							case TPath(dotPath):
								path = dotPath;
								path.first.leadTrivia = removeLeadingTrivia(eobj).concat(path.first.leadTrivia);
								trail = processDotPathTrailingToken(t -> t.removeTrailingTrivia(), path);
							case _:
								throw "asset";
						};

						e.with(kind = TECast({
							syntax: {
								openParen: mkOpenParen(),
								closeParen: mkCloseParen(trail),
								path: path
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

					case TTDictionary(k, v):
						if (k != TTAny || v != TTAny) throwError(exprPos(e), "assert"); // only untyped Dictionary can come from the AS3 `as` cast
						var eAsDictMethod = mkBuiltin("ASDictionary.asDictionary", TTFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(eAsDictMethod, {
							openParen: mkOpenParen(),
							args: [{expr: eobj, comma: null}],
							closeParen: mkCloseParen(removeTrailingTrivia(e))
						}));

					case TTArray(tElem):
						if (tElem != TTAny) throwError(exprPos(e), "assert"); // only TTArray(TTAny) can come from AS3 `as` cast
						if (eobj.type.match(TTArray(_))) {
							// already an array - optimize their `as`es
							processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), eobj);
							eobj.with(expectedType = e.expectedType); // it's important to keep the expected type for further filters
						} else {
							var needsRetype = false;
							var type = switch e.expectedType {
								case TTArray(_): e.expectedType;
								case _: needsRetype = true; tUntypedArray;
							};
							var e = mk(makeAs(eobj, mkBuiltin("Array", TTBuiltin), removeLeadingTrivia(e), removeTrailingTrivia(e)), type, e.expectedType);
							if (needsRetype) e.with(kind = TEHaxeRetype(e)) else e;
						}

					case TTInst(cls) if (cls.name != 'ByteArray'):

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

					case TTInst(cls) if (cls.name == 'ByteArray'):
						e.with(kind = TEHaxeRetype(eobj));

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
		var methodName = if (eObj.type.match(TTAny | TTObject(TTAny))) "dynamicAs" else "reinterpretAs";

		var eMethod = mkBuiltin("ASCompat." + methodName, TTFunction, leadTrivia);
		return TECall(eMethod, {
			openParen: mkOpenParen(),
			args: [
				{expr: eObj, comma: commaWithSpace},
				{expr: eType, comma: null},
			],
			closeParen: mkCloseParen(trailTrivia)
		});
	}

	static function makeStdDowncast(eObj:TExpr, eType:TExpr, leadTrivia, trailTrivia):TExprKind {
		var eMethod = mkBuiltin("cast", TTFunction, leadTrivia);
		return TECall(eMethod, {
			openParen: mkOpenParen(),
			args: [
				{expr: eObj, comma: commaWithSpace},
				{expr: eType, comma: null},
			],
			closeParen: mkCloseParen(trailTrivia)
		});
	}
}
