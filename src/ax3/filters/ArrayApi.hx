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

			// Vector/Array.sort
			case TECall(obj = {kind: TEField({kind: TOExplicit(dot, eVector = {type: TTVector(_) | TTArray(_)})}, "sort", _)}, args):
				// TODO: refactor this a bit, too much duplication here
				var kind = if (eVector.type.match(TTVector(_))) "Vector" else "Array";
				switch args.args {
					case [] if (kind == "Array"):
						var reflectCompareArg = {expr: eReflectCompare, comma: null};
						if (e.expectedType != TTVoid) {
							var eCompatVector = mkBuiltin("ASCompat.ASArray", TTBuiltin, removeLeadingTrivia(eVector));
							e.with(kind = TECall(
								mk(TEField({kind: TOExplicit(dot, eCompatVector), type: eCompatVector.type}, "sort", mkIdent("sort")), TTFunction, TTFunction),
								args.with(args = [{expr: eVector, comma: commaWithSpace}, reflectCompareArg])
							));
						} else {
							e.with(kind = TECall(obj, args.with(args = [reflectCompareArg])));
						}

					case [{expr: {type: TTFunction | TTFun(_)}}]:
						if (e.expectedType != TTVoid) {
							// method used in a value place. AS3 API modifies the vector inplace, but still returns itself
							// for Haxe we could generate `{ expr.sort(); expr; }`, but since `expr` can be a complex
							// expression with possible side-effects, let's just keep it simple and call an ASCompat method
							var eCompatVector = mkBuiltin("ASCompat.AS" + kind, TTBuiltin, removeLeadingTrivia(eVector));
							e.with(kind = TECall(
								mk(TEField({kind: TOExplicit(dot, eCompatVector), type: eCompatVector.type}, "sort", mkIdent("sort")), TTFunction, TTFunction),
								args.with(args = [{expr: eVector, comma: commaWithSpace}, args.args[0]])
							));
						} else {
							// supported by Haxe directly
							e;
						}

					case [eOptions = {expr: {type: TTInt | TTUint}}]:
						var eCompatVector = mkBuiltin("ASCompat.AS" + kind, TTBuiltin, removeLeadingTrivia(eVector));
						e.with(kind = TECall(
							mk(TEField({kind: TOExplicit(dot, eCompatVector), type: eCompatVector.type}, "sortWithOptions", mkIdent("sortWithOptions")), TTFunction, TTFunction),
							args.with(args = [
								{expr: eVector, comma: commaWithSpace},
								eOptions
							])
						));

					case _:
						throwError(exprPos(e), 'Unsupported $kind.sort arguments');
				}

			case TECall(eConcatMethod = {kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_)})}, "concat", fieldToken)}, args):
				switch args.args {
					case []: // concat with no args is just a copy
						var fieldObj = {kind: TOExplicit(dot, eArray), type: eArray.type};
						var eMethod = mk(TEField(fieldObj, "copy", mkIdent("copy", fieldToken.leadTrivia, fieldToken.trailTrivia)), eArray.type, eArray.type);
						e.with(kind = TECall(eMethod, args));

					case [{expr: {type: TTArray(_)}}]:
						// concat with another array - same behaviour as Haxe
						e;

					case [nonArray] if (!nonArray.expr.type.match(TTAny | TTObject(TTAny))):
						// concat with non-array is like a push, that creates a new array instead of mutating the old one
						// Haxe doesn't have this, but we can rewrite it to `a.concat([b])`
						var eArrayDecl = mk(TEArrayDecl({
							syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()},
							elements: [nonArray]
						}), TTArray(nonArray.expr.type), eArray.type);
						e.with(kind = TECall(eConcatMethod, args.with(args = [{expr: eArrayDecl, comma: null}])));

					case _:
						reportError(exprPos(e), "Unhandled Array.concat() call (possibly untyped?). Leaving as is.");
						e;
				}

			// join with no args
			case TECall(eMethod = {kind: TEField({type: TTArray(_)}, "join", fieldToken)}, args = {args: []}):
				e.with(kind = TECall(eMethod, args.with(args = [
					{expr: mk(TELiteral(TLString(mkString(','))), TTString, TTString), comma: null}
				])));

			// push with multiple arguments
			case TECall({kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_) | TTVector(_)})}, methodName = "push" | "unshift", fieldToken)}, args) if (args.args.length > 1):
				var eCompatArray = mkBuiltin("ASCompat.ASArray", TTBuiltin, removeLeadingTrivia(eArray));
				var fieldObj = {kind: TOExplicit(dot, eCompatArray), type: eCompatArray.type};
				var eMethod = mk(TEField(fieldObj, methodName + "Multiple", fieldToken), TTFunction, TTFunction);
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

			// insertAt
			case TECall(eInsertAtMethod = {kind: TEField(fieldObj = {type: TTArray(_)}, "insertAt", insertAtToken)}, args):
				var insertToken = insertAtToken.with(TkIdent, "insert");
				var eInsertMethod = eInsertAtMethod.with(kind = TEField(fieldObj, "insert", insertToken));
				e.with(kind = TECall(eInsertMethod, args));

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

			case _:
				e;
		}
	}
}
