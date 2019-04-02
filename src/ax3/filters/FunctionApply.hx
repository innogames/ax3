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
			case TEField({type: TTFunction | TTFun(_)}, "apply", _):
				throwError(exprPos(e), "closure on Function.apply?");
			case _:
				mapExpr(processExpr, e);
		}
	}
}