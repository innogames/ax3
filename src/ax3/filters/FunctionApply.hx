package ax3.filters;

class FunctionApply extends AbstractFilter {
	static final tcallMethod = TTFun([TTAny, TTFunction, TTArray(TTAny)], TTAny);
	static final eEmptyArray = mk(TEArrayDecl({syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()}, elements: []}), tUntypedArray, tUntypedArray);

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(_, eFun = {type: TTFunction | TTFun(_)})}, "apply", _)}, args):
				eFun = processExpr(eFun);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case []: // no args call, that happens :-/
						e.with(kind = TECall(eFun, args));
					case [thisArg]:
						var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
						if (thisArg.comma == null) thisArg.comma = commaWithSpace;
						e.with(kind = TECall(eCallMethod, args.with(args = [
							thisArg, {expr: eFun, comma: commaWithSpace}, {expr: eEmptyArray, comma: null}
						])));
					case [thisArg, eArgs]:
						var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
						e.with(kind = TECall(eCallMethod, args.with(args = [
							thisArg, {expr: eFun, comma: commaWithSpace}, eArgs
						])));
					case _:
						throwError(exprPos(e), "Invalid Function.apply");
				}

			case TECall({kind: TEField({kind: TOExplicit(_, eFun = {type: TTFunction | TTFun(_)})}, "call", _)}, args):
				eFun = processExpr(eFun);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case []: // no args call, that happens :-/
						e.with(kind = TECall(eFun, args));
					case _[0] => {expr: {kind: TELiteral(TLNull(_))}}: // call with `null` first arg should be the same as simply calling the function
						e.with(kind = TECall(eFun, args.with(args = args.args.slice(1))));
					case _:
						var eArgs = mk(TEArrayDecl({
							syntax: {
								openBracket: mkOpenBracket(),
								closeBracket: mkCloseBracket()
							},
							elements: args.args.slice(1)
						}), tUntypedArray, tUntypedArray);
						var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
						var thisArg = args.args[0];
						if (thisArg.comma == null) thisArg.comma = commaWithSpace;
						e.with(kind = TECall(eCallMethod, args.with(args = [
							thisArg, {expr: eFun, comma: commaWithSpace}, {expr: eArgs, comma: null}
						])));
				}

			case TEField({type: TTFunction | TTFun(_)}, name = "apply" | "call", _):
				throwError(exprPos(e), "closure on Function." + name);

			case _:
				mapExpr(processExpr, e);
		}
	}
}