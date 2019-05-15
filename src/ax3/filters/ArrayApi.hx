package ax3.filters;

class ArrayApi extends AbstractFilter {
	static final tResize = TTFun([TTInt], TTVoid);
	static final tSortOn = TTFun([TTArray(TTAny), TTString, TTInt], TTArray(TTAny));
	static final tInsert = TTFun([TTInt, TTAny], TTVoid);
	static final eReflectCompare = mkBuiltin("Reflect.compare", TTFun([TTAny, TTAny], TTInt));

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			// sort constants
			case TEField({kind: TOExplicit(dot, {kind: TEBuiltin(arrayToken, "Array")})}, fieldName = "CASEINSENSITIVE" | "DESCENDING" | "NUMERIC" | "RETURNINDEXEDARRAY" | "UNIQUESORT", fieldToken):
				var eCompatArray = mkBuiltin("ASCompat.ASArray", TTBuiltin, arrayToken.leadTrivia, arrayToken.trailTrivia);
				var fieldObj = {kind: TOExplicit(dot, eCompatArray), type: TTBuiltin};
				e.with(kind = TEField(fieldObj, fieldName, fieldToken));

			// sortOn
			case TECall({kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_)})}, "sortOn", fieldToken)}, args):
				switch args.args {
					case [eFieldName = {expr: {type: TTString}}, eOptions = {expr: {type: TTInt | TTUint}}]:
						var eCompatArray = mkBuiltin("ASCompat.ASArray", TTBuiltin, removeLeadingTrivia(eArray));
						var fieldObj = {kind: TOExplicit(dot, eCompatArray), type: eCompatArray.type};
						var eMethod = mk(TEField(fieldObj, "sortOn", fieldToken), tSortOn, tSortOn);
						e.with(kind = TECall(eMethod, args.with(args = [
							{expr: eArray, comma: commaWithSpace}, eFieldName, eOptions
						])));
					case _:
						throwError(exprPos(e), "Unsupported Array.sortOn arguments");
				}

			// array.sort()
			case TECall(obj = {kind: TEField({kind: TOExplicit(dot, {type: TTArray(_)})}, "sort", fieldToken)}, args = {args: []}):
				e.with(kind = TECall(obj, args.with(args = [{expr: eReflectCompare, comma: null}])));

			// Vector.sort
			case TECall({kind: TEField({kind: TOExplicit(dot, eVector = {type: TTVector(_)})}, "sort", fieldToken)}, args):
				switch args.args {
					case [{expr: {type: TTFunction | TTFun(_)}}]:
						e; // supported by Haxe
					case [eOptions = {expr: {type: TTInt | TTUint}}]:
						var eCompatVector = mkBuiltin("ASCompat.ASVector", TTBuiltin, removeLeadingTrivia(eVector));
						var fieldObj = {kind: TOExplicit(dot, eCompatVector), type: eCompatVector.type};
						var eMethod = mk(TEField(fieldObj, "sort", fieldToken), tSortOn, tSortOn);
						e.with(kind = TECall(eMethod, args.with(args = [
							{expr: eVector, comma: commaWithSpace}, eOptions
						])));
					case _:
						throwError(exprPos(e), "Unsupported Vector.sort arguments");
				}

			// concat with no args
			case TECall({kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_)})}, "concat", fieldToken)}, args = {args: []}):
				var fieldObj = {kind: TOExplicit(dot, eArray), type: eArray.type};
				var eMethod = mk(TEField(fieldObj, "copy", mkIdent("copy", fieldToken.leadTrivia, fieldToken.trailTrivia)), eArray.type, eArray.type);
				e.with(kind = TECall(eMethod, args));

			// join with no args
			case TECall(eMethod = {kind: TEField({type: TTArray(_)}, "join", fieldToken)}, args = {args: []}):
				e.with(kind = TECall(eMethod, args.with(args = [
					{expr: mk(TELiteral(TLString(new Token(0, TkStringDouble, '","', [], []))), TTString, TTString), comma: null}
				])));

			// push with multiple arguments
			case TECall({kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_)})}, "push", fieldToken)}, args) if (args.args.length > 1):
				var eCompatArray = mkBuiltin("ASCompat.ASArray", TTBuiltin, removeLeadingTrivia(eArray));
				var fieldObj = {kind: TOExplicit(dot, eCompatArray), type: eCompatArray.type};
				var eMethod = mk(TEField(fieldObj, "pushMultiple", fieldToken), TTFunction, TTFunction);
				e.with(kind = TECall(eMethod, args.with(args = [{expr: eArray, comma: commaWithSpace}].concat(args.args))));

			// set length
			case TEBinop({kind: TEField(to = {kind: TOExplicit(dot, eArray), type: TTArray(_)}, "length", _)}, op = OpAssign(_), eNewLength):
				if (e.expectedType == TTVoid) {
					// block-level length assignment - safe to just call Haxe's "resize" method
					e.with(
						kind = TECall(
							mk(TEField(to, "resize", mkIdent("resize")), tResize, tResize),
							{
								openParen: mkOpenParen(),
								closeParen: mkCloseParen(),
								args: [{expr: eNewLength, comma: null}]
							}
						)
					);
				} else {
					// possibly value-level length assignment - need to call compat method
					var eCompatMethod = mkBuiltin("ASCompat.arraySetLength", TTFunction, removeLeadingTrivia(eArray), []);
					e.with(kind = TECall(eCompatMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(),
						args: [
							{expr: eArray, comma: commaWithSpace},
							{expr: eNewLength, comma: null}
						]
					}));
				}

			// splice
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eArray), type: t = TTArray(_) | TTVector(_)}, "splice", _)}, args):
				var isVector = t.match(TTVector(_));
				var methodNamePrefix = if (isVector) "vector" else "array";

				switch args.args {
					case [eIndex, {expr: {kind: TELiteral(TLInt({text: "0"}))}}, eInserted]:
						// this is a special case that we want to rewrite to a nice `array.insert(pos, elem)`
						// but only if the value is not used (because `insert` returns Void, while splice returns `Array`)
						if (e.expectedType == TTVoid) {
							var methodName = if (isVector) "insertAt" else "insert";
							var eMethod = mk(TEField(fieldObj, methodName, mkIdent(methodName)), tInsert, tInsert);
							mk(TECall(eMethod, args.with(args = [eIndex, eInserted])), TTVoid, TTVoid);
						} else {
							e;
						}

					case [_, _]:
						// just two arguments - no inserted values, so it's a splice just like in Haxe, leave as is
						e;

					case [eIndex]: // single arg - remove everything beginning with the given index
						var eCompatMethod = mkBuiltin('ASCompat.${methodNamePrefix}SpliceAll', TTFunction, removeLeadingTrivia(eArray), []);
						e.with(kind = TECall(eCompatMethod, args.with(
							args = [
								{expr: eArray, comma: commaWithSpace},
								eIndex
							]
						)));

					case _:
						if (args.args.length < 3) throw "assert";

						// rewrite anything else to a compat call
						var eCompatMethod = mkBuiltin('ASCompat.${methodNamePrefix}Splice', TTFunction, removeLeadingTrivia(eArray), []);

						var newArgs = [
							{expr: eArray, comma: commaWithSpace}, // array instance
							args.args[0], // index
							args.args[1], // delete count
							{
								expr: mk(TEArrayDecl({
									syntax: {
										openBracket: mkOpenBracket(),
										closeBracket: mkCloseBracket()
									},
									elements: [for (i in 2...args.args.length) args.args[i]]
								}), tUntypedArray, tUntypedArray),
								comma: null,
							}
						];

						e.with(kind = TECall(eCompatMethod, args.with(args = newArgs)));
				}

			case TECall({kind: TEVector(_, elemType)}, args):
				switch args.args {
					case [{expr: eOtherVector = {type: TTVector(actualElemType)}}]:
						if (Type.enumEq(elemType, actualElemType)) {
							reportError(exprPos(e), "Useless vector casting");
							processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), eOtherVector);
							processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(removeTrailingTrivia(e)), eOtherVector);
							eOtherVector.with(expectedType = e.expectedType);
						} else {
							var convertMethod = mkBuiltin("flash.Vector.convert", TTFunction, removeLeadingTrivia(e));
							e.with(kind = TECall(convertMethod, args));
						}

					case [eArray = {expr: {type: TTArray(_) | TTAny}}]:
						var convertMethod = mkBuiltin("flash.Vector.ofArray", TTFunction, removeLeadingTrivia(e));
						var eArrayExpr = eArray.expr;

						switch eArrayExpr.type {
							case TTArray(arrayElemType) if (Type.enumEq(elemType, arrayElemType)):
								// same type, nothing to do \o/
							case _:
								// add type cast
								var t = TTArray(elemType); // TODO: support inserting `cast` in TEHaxeRetype
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
}
