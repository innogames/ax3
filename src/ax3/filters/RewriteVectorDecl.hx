package ax3.filters;

class RewriteVectorDecl extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEVectorDecl(v = {elements: {elements: []}}):
				// rewrite to just `new Vector<T>()`
				var newKeyword = v.syntax.newKeyword;
				if (newKeyword.trailTrivia.length == 0) {
					newKeyword.trailTrivia.push(whitespace);
				}
				e.with(kind = TENew(newKeyword, TNType({
					type: TTVector(v.type),
					syntax: TVector({
						name: mkIdent("Vector"),
						dot: mkDot(),
						t: v.syntax.typeParam
					})
				}), {
					openParen: new Token(v.elements.syntax.openBracket.pos, TkParenOpen, "(", v.elements.syntax.openBracket.leadTrivia, v.elements.syntax.openBracket.trailTrivia),
					args: [],
					closeParen: new Token(v.elements.syntax.closeBracket.pos, TkParenClose, ")", v.elements.syntax.closeBracket.leadTrivia, v.elements.syntax.closeBracket.trailTrivia)
				}));

			case TEVectorDecl(v):
				// rewrite to Vector.ofArray, adding a type-check if needed
				var eConvertMethod = mkBuiltin("Vector.ofArray", TTFunction, v.syntax.newKeyword.leadTrivia);
				var tArray = TTArray(v.type);
				var eArrayDecl = mk(TEArrayDecl(v.elements), tArray, tArray);
				var trailTrivia = removeTrailingTrivia(eArrayDecl);

				if (arrayDeclNeedsTypeCheck(v.elements, v.type)) {
					eArrayDecl = eArrayDecl.with(kind = TEHaxeRetype(eArrayDecl));
				}

				e.with(kind = TECall(eConvertMethod, {
					openParen: mkOpenParen(),
					args: [{expr: eArrayDecl, comma: null}],
					closeParen: new Token(v.elements.syntax.closeBracket.pos, TkParenClose, ")", [], trailTrivia)
				}));

			case TECall({kind: TEVector(v, elemType)}, args):
				switch args.args {
					case [{expr: eOtherVector = {type: TTVector(actualElemType)}}]:
						if (typeEq(elemType, actualElemType)) {
							reportError(exprPos(e), "Useless vector casting");
							processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), eOtherVector);
							processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), eOtherVector);
							eOtherVector.with(expectedType = e.expectedType);
						} else {
							var convertMethod = mkBuiltin("Vector.convert", TTFunction, removeLeadingTrivia(e));
							e = e.with(kind = TECall(convertMethod, args));
							if (typeEq(e.expectedType, TTVector(elemType))) {
								e;
							} else {
								e.with(kind = TEHaxeRetype(e));
							}
						}

					case [{expr: {kind: TEArrayDecl({elements: []})}}]:
						// Vector.<T>([]) - rewrite to `new Vector<T>()`
						var leadTrivia = v.name.leadTrivia;
						v.name.leadTrivia = [];
						var newKeyword = mkIdent("new", leadTrivia, [whitespace]);
						e.with(kind = TENew(newKeyword, TNType({type: TTVector(elemType), syntax: TVector(v)}), args.with(args = [])));

					case [eArray = {expr: {type: TTArray(_) | TTAny}}]:
						var convertMethod = mkBuiltin("Vector.ofArray", TTFunction, removeLeadingTrivia(e));
						var eArrayExpr = eArray.expr;

						switch eArrayExpr {
							case {type: TTArray(arrayElemType)} if (typeEq(elemType, arrayElemType)):
								// same type, nothing to do \o/
							case {kind: TEArrayDecl(arr)} if (!arrayDeclNeedsTypeCheck(arr, elemType)):
								// array decl with all elements conforming
							case _:
								// add type cast
								var t = TTArray(elemType);
								var eRetypedArray = eArray.with(expr = mk(TEHaxeRetype(eArrayExpr.with(expectedType = t)), t, t));
								args = args.with(args = [eRetypedArray]);
						}
						e.with(kind = TECall(convertMethod, args));

					case _:
						throwError(exprPos(e), "Unsupported Vector<...> call");
				}

			case _:
				e;
		}
	}

	static function arrayDeclNeedsTypeCheck(decl:TArrayDecl, expectedElemType:TType):Bool {
		for (e in decl.elements) {
			if (!typeEq(e.expr.type, expectedElemType)) {
				return true;
			}
		}
		return false;
	}
}
