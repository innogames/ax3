package ax3.filters;

private typedef IntIterInfo = {itName:Token, vit:TVar, iter:TExpr};

class RewriteCFor extends AbstractFilter {
	var currentIncrExpr:Null<TExpr>; // TODO: handle comma here for the nicer output

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEFor(f):
				// TODO: also detect `for (var i = 0; i < array.length; i++) { var elem = array[i]; ... }`
				// we can safely rewrite it to `for (elem in array)` if no mutating methods are called and array itself is not passed over
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
		// TODO: check for modifications of the loop var and cancel (although Haxe compiler will check for that)
		var initVarDecl, endValue;
		switch f.einit {
			// TODO: also check for TELocal, but introduce temp var similar to what we do on `for( each)` type mismatches
			case {kind: TEVars(_, [varDecl = {v: {type: TTInt | TTUint}}])} if (varDecl.init != null):
				initVarDecl = varDecl;
			case _:
				return null;
		}

		switch f.econd {
			case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpLt(_), b = {kind: TELocal(_, endValueVar), type: TTInt | TTUint})} if (checkedVar == initVarDecl.v):
				// TODO maybe also allow constant fields, although I'm not sure how many instance of that we have :)
				if (isEndValueModified(endValueVar, f.body)) {
					return null;
				}
				endValue = b;
			case _:
				return null;
		}

		switch f.eincr {
			// TODO: also check for `<=` and add `+1` to `endValue`?
			case {kind: TEPreUnop(PreIncr(_), {kind: TELocal(_, checkedVar)})} if (checkedVar == initVarDecl.v):
			case {kind: TEPostUnop({kind: TELocal(_, checkedVar)}, PostIncr(_))} if (checkedVar == initVarDecl.v):
			case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpAssignOp(AOpAdd(_)), {kind: TELiteral(TLInt({text: "1"}))})} if (checkedVar == initVarDecl.v):
			case _:
				return null;
		}

		return {
			itName: initVarDecl.syntax.name,
			vit: initVarDecl.v,
			iter: mk(TEHaxeIntIter(initVarDecl.init.expr, endValue), TTBuiltin, TTBuiltin)
		};
	}

	static function isEndValueModified(v:TVar, e:TExpr) {
		var result = false;
		function loop(e:TExpr):TExpr {
			return switch e.kind {
				case TEBinop({kind: TELocal(_, modifiedVar)}, OpAssign(_) | OpAssignOp(_), _)
				   | TEPreUnop(PreIncr(_) | PreDecr(_), {kind: TELocal(_, modifiedVar)})
				   | TEPostUnop({kind: TELocal(_, modifiedVar)}, PostIncr(_) | PostDecr(_))
				   if (modifiedVar == v):
					result = true;
					e;
				case _:
					mapExpr(loop, e); // TODO: i really need an iterExpr function with a way to exit early
			}
		}
		loop(e);
		return result;
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
