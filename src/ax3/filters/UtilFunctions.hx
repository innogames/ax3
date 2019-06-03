package ax3.filters;

class UtilFunctions extends AbstractFilter {
	static final tResolveClass = TTFun([TTString], TTClass);

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall(eobj = {kind: TEDeclRef(_, {kind: TDFunction({parentModule: {name: "getDefinitionByName", parentPack: {name: "flash.utils"}}})})}, args):
				switch args.args {
					case [_]:
						var eResolveClass = mkBuiltin("Type.resolveClass", tResolveClass, removeLeadingTrivia(eobj), removeTrailingTrivia(eobj));
						e.with(kind = TECall(eResolveClass, args));
					case _:
						throwError(exprPos(e), "Invalid getDefinitionByName args");
				}
			case _:
				mapExpr(processExpr, e);
		}
	}
}
