package ax3.filters;

private typedef IntIterInfo = {itName:Token, vit:TVar, iter:TExpr};

class RewriteCFor extends AbstractFilter {
	var currentIncrExpr:Null<TExpr>; // TODO: handle comma here for the nicer output

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEFor(f):
				switch getSimpleSequence(f) {
					case null:
						rewriteToWhile(f);
					case s:
						rewriteToIntIter(f, s);
				}
			case TEContinue(_):
				if (currentIncrExpr != null) concatExprs(currentIncrExpr, e) else e;
			case _:
				mapExpr(processExpr, e);
		}
	}

	static function getSimpleSequence(f:TFor):Null<IntIterInfo> {
		return null; // TODO: disabled for now because of length-mutating loops over the index doesn't play well with this, gotta check if `endValue` is immutable

		// TODO: check for modifications of the loop var and cancel
		// TODO: maybe check whether `endValue` is really immutable, because Haxe will store it in a temp var
		var initVarDecl, endValue;
		switch f.einit {
			// TODO: also check for TELocal, but introduce temp var similar to what we do on `for( each)` type mismatches
			case {kind: TEVars(_, [varDecl = {v: {type: TTInt | TTUint}}])} if (varDecl.init != null): initVarDecl = varDecl;
			case _: return null;
		}

		switch f.econd {
			case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpLt(_), b = {type: TTInt | TTUint})} if (checkedVar == initVarDecl.v): endValue = b;
			case _: return null;
		}

		switch f.eincr {
			// TODO: also check for `<=` and add `+1` to `endValue`?
			case {kind: TEPreUnop(PreIncr(_), {kind: TELocal(_, checkedVar)})} if (checkedVar == initVarDecl.v):
			case {kind: TEPostUnop({kind: TELocal(_, checkedVar)}, PostIncr(_))} if (checkedVar == initVarDecl.v):
			case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpAssignOp(AOpAdd(_)), {kind: TELiteral(TLInt({text: "1"}))})} if (checkedVar == initVarDecl.v):
			case _: return null;
		}

		return {
			itName: initVarDecl.syntax.name,
			vit: initVarDecl.v,
			iter: mk(TEHaxeIntIter(initVarDecl.init.expr, endValue), TTBuiltin, TTBuiltin)
		};
	}

	function rewriteToIntIter(f:TFor, s:IntIterInfo):TExpr {
		return mk(TEHaxeFor({
			syntax: {
				forKeyword: f.syntax.keyword,
				openParen: f.syntax.openParen,
				itName: s.itName,
				inKeyword: mkTokenWithSpaces(TkIdent, "in"),
				closeParen: f.syntax.closeParen
			},
			vit: s.vit,
			iter: s.iter,
			body: processExpr(f.body)
		}), TTVoid, TTVoid);
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
