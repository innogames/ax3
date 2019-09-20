package ax3.filters;

private typedef IntIterInfo = {
	final loopVar:TVar;
	final iterator:TExpr;
	final assignment:Null<TExpr>;
}

class RewriteCFor extends AbstractFilter {
	static inline final tempLoopVarName = "_tmp_";
	public static inline final reverseIntIterBuiltin = "reverseIntIter";

	public static var reverseIntIterUsed(default,null) = false;

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
				if (currentIncrExpr != null) {

					var incrExpr = cloneExpr(currentIncrExpr);
					processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(e).concat(t.leadTrivia), incrExpr);

					mkMergedBlock([
						{expr: incrExpr, semicolon: mkSemicolon()},
						{expr: e, semicolon: mkSemicolon()},
					]);
				} else {
					e;
				}

			case _:
				mapExpr(processExpr, e);
		}
	}

	static function getSimpleSequence(f:TFor):Null<IntIterInfo> {
		var originalLoopVar, loopVar, startValue, endValue;
		var assignment;
		switch f.einit {
			case {kind: TEVars(_, [varDecl = {v: {type: TTInt | TTUint}}])} if (varDecl.init != null):
				loopVar = originalLoopVar = varDecl.v;
				startValue = varDecl.init.expr;
				assignment = null;
			case {kind: TEBinop(eLoopLocal = {kind: TELocal(_, v)}, op = OpAssign(_), eInit)}:
				originalLoopVar = v;
				loopVar = {name: tempLoopVarName, type: v.type};
				startValue = eInit;
				assignment = mk(TEBinop(eLoopLocal, op, mk(TELocal(mkIdent(tempLoopVarName), loopVar), v.type, v.type)), v.type, TTVoid);
			case _:
				return null;
		}

		if (isLocalVarModified(originalLoopVar, f.body)) {
			return null;
		}

		var isReverse;
		switch f.econd {
			case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpLt(_), b = {type: TTInt | TTUint})} if (checkedVar == originalLoopVar):
				if (isValidSimpleSequenceEndValueExpr(b, f.body)) {
					endValue = b;
					isReverse = false;
				} else {
					return null;
				}

			case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpGte(_), b = {type: TTInt | TTUint})} if (checkedVar == originalLoopVar):
				if (isValidSimpleSequenceEndValueExpr(b, f.body)) {
					endValue = b;
					isReverse = true;
				} else {
					return null;
				}

			case _:
				return null;
		}

		if (!isReverse) {
			switch f.eincr {
				// TODO: also check for `<=` and add `+1` to `endValue`?
				case {kind: TEPreUnop(PreIncr(_), {kind: TELocal(_, checkedVar)})} if (checkedVar == originalLoopVar):
				case {kind: TEPostUnop({kind: TELocal(_, checkedVar)}, PostIncr(_))} if (checkedVar == originalLoopVar):
				case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpAssignOp(AOpAdd(_)), {kind: TELiteral(TLInt({text: "1"}))})} if (checkedVar == originalLoopVar):
				case _:
					return null;
			}
		} else {
			switch f.eincr {
				// TODO: also check for `>` and add `-1` to `endValue`?
				case {kind: TEPreUnop(PreDecr(_), {kind: TELocal(_, checkedVar)})} if (checkedVar == originalLoopVar):
				case {kind: TEPostUnop({kind: TELocal(_, checkedVar)}, PostDecr(_))} if (checkedVar == originalLoopVar):
				case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpAssignOp(AOpSub(_)), {kind: TELiteral(TLInt({text: "1"}))})} if (checkedVar == originalLoopVar):
				case _:
					return null;
			}
		}

		var iterator = mk(TEHaxeIntIter(startValue, endValue), TTBuiltin, TTBuiltin);
		if (isReverse) {
			var reverseIntIter = mk(TEBuiltin(mkIdent(reverseIntIterBuiltin, removeLeadingTrivia(iterator)), reverseIntIterBuiltin), TTBuiltin, TTBuiltin);
			iterator = mkCall(reverseIntIter, [iterator], TTBuiltin, removeTrailingTrivia(iterator));
			reverseIntIterUsed = true;
		}

		return {
			loopVar: loopVar,
			iterator: iterator,
			assignment: assignment,
		};
	}

	static function isValidSimpleSequenceEndValueExpr(e:TExpr, loopBody:TExpr):Bool {
		return switch e.kind {
			case TELocal(_, endValueVar) if (!isLocalVarModified(endValueVar, loopBody)):
				true;

			case TEField({type: TTStatic(cls)}, fieldName, _):
				var field = cls.findField(fieldName, true);
				if (field == null) throw "assert";
				switch field.kind {
					case TFVar({kind: VConst(_)}):
						true;
					case _:
						false;
				}

			case TELiteral(_):
				true;

			case _:
				false;
		}
	}

	static function isLocalVarModified(v:TVar, e:TExpr) {
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
				itName: mkIdent(s.loopVar.name),
				inKeyword: mkTokenWithSpaces(TkIdent, "in"),
				closeParen: f.syntax.closeParen
			},
			vit: s.loopVar,
			iter: s.iterator,
			body: {
				var body = processExpr(f.body);
				if (s.assignment == null) body else concatExprs(s.assignment, body);
			}
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
			processLeadingToken(t -> t.leadTrivia = f.syntax.keyword.leadTrivia.concat(t.leadTrivia), f.einit);
			return mkMergedBlock([
				{expr: f.einit, semicolon: mkSemicolon()},
				{expr: ewhile, semicolon: null}
			]);
		} else {
			return ewhile;
		}
	}
}
