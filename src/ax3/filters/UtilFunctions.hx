package ax3.filters;

class UtilFunctions extends AbstractFilter {
	static final tResolveClass = TTFun([TTString], TTClass);
	static final tGetTimer = TTFun([], TTInt);
	static final tDescribeType = TTFun([TTAny], TTXML);
	static final tGetUrl = TTFun([TTAny/*TODO:URLRequest*/, TTString], TTVoid);

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "getDefinitionByName", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("Type.resolveClass", tResolveClass, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "getTimer", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("flash.Lib.getTimer", tGetTimer, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "describeType", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("flash.Lib.describeType", tDescribeType, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "clearTimeout", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("ASCompat.clearTimeout", TTFunction, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "setTimeout", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("ASCompat.setTimeout", TTFunction, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "navigateToURL", parentPack: {name: "flash.net"}}})}):
				mkBuiltin("flash.Lib.getURL", tGetUrl, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case _:
				mapExpr(processExpr, e);
		}
	}
}
