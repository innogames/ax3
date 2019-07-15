package ax3.filters;

class UtilFunctions extends AbstractFilter {
	static final tResolveClass = TTFun([TTString], TTClass);
	static final tGetTimer = TTFun([], TTInt);
	static final tDescribeType = TTFun([TTAny], TTXML);
	static final tGetUrl = TTFun([TTAny/*TODO:URLRequest*/, TTString], TTVoid);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "getDefinitionByName", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("Type.resolveClass", tResolveClass, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TECall({kind: TEBuiltin(_, "Type.resolveClass")}, _):
				// `getDefinitionByName` returns Object, but `Type.resolveClass` can only return Class, so fix the type of its calls
				e.with(type = TTClass);
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "getTimer", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("flash.Lib.getTimer", tGetTimer, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "describeType", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("ASCompat.describeType", tDescribeType, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: methodName = "clearTimeout" | "setTimeout" | "clearInterval" | "setInterval", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("ASCompat." + methodName, TTFunction, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "navigateToURL", parentPack: {name: "flash.net"}}})}):
				mkBuiltin("flash.Lib.getURL", tGetUrl, removeLeadingTrivia(e), removeTrailingTrivia(e));
			// case TECall({kind: TEDeclRef(_, {kind: TDFunction({parentModule: {name: "getQualifiedClassName", parentPack: {name: "flash.utils"}}})})}, args):
			// 	switch args.args {
			// 		case [{expr: {type: TTClass | TTStatic(_)}}]:
			// 			var eGetClassName = mkBuiltin("Type.getClassName", TTFunction, removeLeadingTrivia(e));
			// 			e.with(kind = TECall(eGetClassName, args));
			// 		case [arg]:
			// 			// TODO: maybe we should have a compat function here instead, because calling native getQualifiedClassName is faster
			// 			var eGetClass = mkBuiltin("Type.getClass", TTFunction);
			// 			var eGetClassCall = mk(TECall(eGetClass, {
			// 				openParen: mkOpenParen(),
			// 				args: [arg],
			// 				closeParen: mkCloseParen()
			// 			}), TTClass, TTClass);
			// 			var eGetClassName = mkBuiltin("Type.getClassName", TTFunction, removeLeadingTrivia(e));
			// 			e.with(kind = TECall(eGetClassName, args.with(args = [{expr: eGetClassCall, comma: null}])));
			// 		case _:
			// 			throwError(exprPos(e), "Invalid getQualifiedClassName arguments");
			// 	}
			case _:
				e;
		}
	}
}
