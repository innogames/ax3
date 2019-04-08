package ax3.filters;

class ArrayApi extends AbstractFilter {
	static final tResize = TTFun([TTInt], TTVoid);
	static final tSortOn = TTFun([TTArray(TTAny), TTString, TTInt], TTArray(TTAny));

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
				eArray = processExpr(eArray);
				args = mapCallArgs(processExpr, args);
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

			// push with multiple arguments
			case TECall(ePush = {kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_)})}, "push", fieldToken)}, args) if (args.args.length > 1):
				eArray = processExpr(eArray);
				args = mapCallArgs(processExpr, args);

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
			case TECall({kind: TEField({kind: TOExplicit(_, eArray), type: t = TTArray(_) | TTVector(_)}, "splice", _)}, args):
				var isVector = t.match(TTVector(_));
				var methodNamePrefix = if (isVector) "vector" else "array";

				switch args.args {
					// case [eIndex, {expr: {kind: TELiteral(TLInt({text: "0"}))}}, eInserted]:
						// this is a special case that we want to rewrite to a nice `array.insert(pos, elem)`
						// but only if the value is not used (because `insert` returns Void, while splice returns `Array`)
						// TODO: enable this (needs making sure that the value is unused)
						// e;

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

			case TECall({kind: TEVector(_)}, args):
				switch args.args {
					case [{expr: {type: TTVector(_)}}]:
						var convertMethod = mkBuiltin("flash.Vector.convert", TTFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(convertMethod, args));

					case [{expr: {type: TTArray(_) | TTAny}}]:
						var convertMethod = mkBuiltin("flash.Vector.ofArray", TTFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(convertMethod, args));

					case _:
						throwError(exprPos(e), "Unsupported Vector<...> call");
				}
			case _:
				e;
		}
	}
}
