package ax3.filters;

import ax3.ParseTree.TypeHint;

class RestArgs extends AbstractFilter {
	override function processSignature(sig:TFunctionSignature):TFunctionSignature {
		if (sig.args.length > 0) {
			var lastArg = sig.args[sig.args.length - 1];
			switch lastArg.kind {
				case TArgNormal(_):
					// nothing to do
				case TArgRest(dots):
					var hint:TypeHint = {
						colon: new Token(0, TkColon, ":", [], []),
						type: TPath({first: new Token(0, TkIdent, "Array", [], []), rest: []})
					};
					lastArg.kind = TArgNormal(hint, {
						equalsToken: new Token(0, TkEquals, "=", [whitespace], [whitespace]),
						expr: mkNullExpr(TTArray(TTAny)) // TODO: actually we have to add a null check and assign `[]` there, but it's not what current converter does and people is okay with it, it seems
					});
					var dotsTrivia = dots.leadTrivia.concat(dots.trailTrivia);
					lastArg.syntax.name.leadTrivia = dotsTrivia.concat(lastArg.syntax.name.leadTrivia);
			}
		}
		return sig;
	}

	override function processExpr(e:TExpr):TExpr {
		mapExpr(processExpr, e);
		switch e.kind {
			case TELocalFunction(f):
				f.fun.sig = processSignature(f.fun.sig);
			case TECall(eobj = {type: TTFun(argTypes, _, TRestAs3)}, args) if (args.args.length > argTypes.length):
				var normalArgs = args.args.slice(0, argTypes.length);
				var restArgs = args.args.slice(argTypes.length);

				var lead = removeLeadingTrivia(restArgs[0].expr);
				var trail = removeTrailingTrivia(restArgs[restArgs.length - 1].expr);

				normalArgs.push({
					expr: mk(TEArrayDecl({
						syntax: {
							openBracket: new Token(0, TkBracketOpen, "[", lead, []),
							closeBracket: new Token(0, TkBracketClose, "]", [], trail),
						},
						elements: restArgs
					}), tUntypedArray, tUntypedArray),
					comma: null
				});
				args.args = normalArgs;
			case _:
		}
		return e;
	}
}