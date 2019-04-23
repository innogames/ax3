package ax3.filters;

class FixNonInlineableDefaultArgs extends AbstractFilter {
	override function processFunction(fun:TFunction) {
		if (fun.expr == null) return;
		var initExprs = [];
		for (arg in fun.sig.args) {
			switch arg.kind {
				case TArgNormal(type, init = {expr: {kind: TEField({type: TTStatic(cls)}, fieldName, fieldToken)}}):
					switch cls.findField(fieldName, true) {
						case {kind: TFVar(f)}:
							if (!f.isInline) {
								// TODO: handle trivias
								var eLocal = mk(TELocal(mkIdent(arg.name), arg.v), arg.v.type, arg.v.type);
								var check = mk(TEIf({
									syntax: {
										keyword: addTrailingWhitespace(mkIdent("if")),
										openParen: mkOpenParen(),
										closeParen: addTrailingWhitespace(mkCloseParen())
									},
									econd: mk(TEBinop(eLocal, OpEquals(mkEqualsEqualsToken()), mkNullExpr()), TTBoolean, TTBoolean),
									ethen: mk(TEBinop(eLocal, OpAssign(new Token(0, TkEquals, "=", [whitespace], [whitespace])), init.expr), eLocal.type, eLocal.type),
									eelse: null
								}), TTVoid, TTVoid);
								initExprs.push({
									expr: check,
									semicolon: addTrailingNewline(mkSemicolon()),
								});
								arg.kind = TArgNormal(type, init.with(expr = mkNullExpr()));
							}

						case _:
							throwError(init.equalsToken.pos, "Unsupported default arg initialization");
					}
				case _:
			}
		}
		if (initExprs.length > 0) {
			var initBlock = mk(TEBlock({
				syntax: {
					openBrace: mkOpenBrace(),
					closeBrace: mkCloseBrace()
				},
				exprs: initExprs,
			}), TTVoid, TTVoid);
			fun.expr = concatExprs(initBlock, fun.expr);
		}
	}
}
