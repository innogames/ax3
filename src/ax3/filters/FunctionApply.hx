package ax3.filters;

class FunctionApply extends AbstractFilter {
	static final tcallMethod = TTFun([TTAny, TTFunction, TTArray(TTAny)], TTAny);

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(_, eFun = {type: TTFunction | TTFun(_)})}, "apply", _)}, args):
				switch args.args {
					case [eThis, eArgs]:
						eFun = processExpr(eFun);
						args = mapCallArgs(processExpr, args);
						var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
						e.with(kind = TECall(eCallMethod, args.with(args = [
							eThis, {expr: eFun, comma: commaWithSpace}, eArgs
						])));
					case _:
						throwError(exprPos(e), "Invalid Function.apply");
				}

			case TECall({kind: TEField({kind: TOExplicit(_, eFun = {type: TTFunction | TTFun(_)})}, "call", _)}, args):
				eFun = processExpr(eFun);
				switch args.args {
					case []: // no args call, that happens :-/
						e.with(kind = TECall(eFun, args));
					case _:
						args = mapCallArgs(processExpr, args);
						var eArgs = mk(TEArrayDecl({
							syntax: {
								openBracket: mkOpenBracket(),
								closeBracket: mkCloseBracket()
							},
							elements: args.args.slice(1)
						}), tUntypedArray, tUntypedArray);
						var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
						e.with(kind = TECall(eCallMethod, args.with(args = [
							args.args[0], {expr: eFun, comma: commaWithSpace}, {expr: eArgs, comma: null}
						])));
				}

			case TEField({type: TTFunction | TTFun(_)}, name = "apply" | "call", _):
				throwError(exprPos(e), "closure on Function." + name);

			case _:
				mapExpr(processExpr, e);
		}
	}
}