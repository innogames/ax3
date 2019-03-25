package ax3.filters;

class RewriteCFor extends AbstractFilter {
	var currentIncrExpr:Null<TExpr>; // TODO: handle comma here for the nicer output

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEFor(f):
				if (isSimpleSequence(f)) {
					// rewriteToIntIter(f);
					mapExpr(processExpr, e);
				} else {
					rewriteToWhile(f);
				}
			case TEContinue(_):
				if (currentIncrExpr != null) concatExprs(currentIncrExpr, e) else e;
			case _:
				mapExpr(processExpr, e);
		}
	}

	static function isSimpleSequence(f:TFor):Bool {
		var initVarDecl, endValue;
		switch f.einit {
			case {kind: TEVars(_, [varDecl = {v: {type: TTInt | TTUint}, init: init}])} if (init != null): initVarDecl = varDecl;
			case _: return false;
		}

		switch f.econd {
			case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpLt(_), b)} if (checkedVar == initVarDecl.v): endValue = b;
			case _: return false;
		}

		switch f.eincr {
			case {kind: TEPreUnop(PreIncr(_), {kind: TELocal(_, checkedVar)})} if (checkedVar == initVarDecl.v):
			case {kind: TEPostUnop({kind: TELocal(_, checkedVar)}, PostIncr(_))} if (checkedVar == initVarDecl.v):
			case _: return false;
		}

		return true;
	}

	function rewriteToIntIter(f:TFor):TExpr {
		trace("INT ITER");
		return mk(TEFor(f), TTVoid, TTVoid);
	}

	function rewriteToWhile(f:TFor):TExpr {
		var cond = if (f.econd != null) f.econd else mk(TELiteral(TLBool(new Token(0, TkIdent, "true", [], []))), TTBoolean, TTBoolean);

		var oldIncrExpr = currentIncrExpr;
		currentIncrExpr = f.eincr;
		var body = processExpr(f.body);
		currentIncrExpr = oldIncrExpr;

		var body = if (f.eincr == null) body else concatExprs(body, f.eincr);

		var ewhile = mk(TEWhile({
			syntax: {
				keyword: new Token(0, TkIdent, "while", if (f.einit != null) [] else f.syntax.keyword.leadTrivia, f.syntax.keyword.trailTrivia),
				openParen: f.syntax.openParen,
				closeParen: f.syntax.closeParen,
			},
			cond: cond,
			body: body
		}), TTVoid, TTVoid);

		if (f.einit != null) {
			return mk(TEBlock({
				syntax: {
					openBrace: new Token(0, TkBraceOpen, "{", f.syntax.keyword.leadTrivia, []),
					closeBrace: new Token(0, TkBraceClose, "}", [], removeTrailingTrivia(body)),
				},
				exprs: [
					{expr: f.einit, semicolon: mkSemicolon()},
					{expr: ewhile, semicolon: null}
				]
			}), TTVoid, TTVoid);
		} else {
			return ewhile;
		}
	}
}
