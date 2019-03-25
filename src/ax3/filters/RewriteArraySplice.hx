package ax3.filters;

class RewriteArraySplice extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch (e.kind) {
			case TECall({kind: TEField({kind: TOExplicit(_, eArray), type: TTArray(_)}, "splice", _)}, args):
				switch args.args {
					// case [eIndex, {expr: {kind: TELiteral(TLInt({text: "0"}))}}, eInserted]:
						// this is a special case that we want to rewrite to a nice `array.insert(pos, elem)`
						// but only if the value is not used (because `insert` returns Void, while splice returns `Array`)
						// TODO: enable this (needs making sure that the value is unused)
						// e;
					case [_, _]:
						// just two arguments - no inserted values, so it's a splice just like in Haxe, leave as is
						e;
					case _:
						// rewrite anything else to a compat call
						var leadTrivia = removeLeadingTrivia(eArray);
						var eCompatMethod = mk(TEBuiltin(new Token(0, TkIdent, "ASCompat.arraySplice", leadTrivia, []), "ASCompat.arraySplice"), TTFunction, TTFunction);

						var newArgs = [
							{expr: eArray, comma: new Token(0, TkComma, ",", [], [mkWhitespace()])}, // array instance
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
		};
	}
}
