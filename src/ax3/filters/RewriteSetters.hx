package ax3.filters;

class RewriteSetters extends AbstractFilter {
	override function processSetter(field:TAccessorField) {
		var sig = field.fun.sig;
		var arg = sig.args[0];
		var type = arg.type;
		sig.ret = {
			type: type,
			syntax: null
		};
		var returnKeyword = new Token(0, TkIdent, "return", [], [new Trivia(TrWhitespace, " ")]);
		var argLocal = mk(TELocal(mkIdent(arg.name), arg.v), arg.v.type, arg.v.type);
		var returnExpr = mk(TEReturn(returnKeyword, argLocal), TTVoid, TTVoid);
		field.fun.expr = concatExprs(field.fun.expr, returnExpr);
	}
}