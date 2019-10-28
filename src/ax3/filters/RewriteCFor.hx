package ax3.filters;

private typedef IntIterInfo = {
	final loopVar:TVar;
	final iterator:TExpr;
	final assignment:Null<TExpr>;
}

class RewriteCFor extends AbstractFilter {
	static inline final tempLoopVarName = "_tmp_";

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

	static final literalOne = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "1", [], []))), TTInt, TTInt);
	static final opAdd = OpAdd(new Token(0, TkPlus, "+", [whitespace], [whitespace]));

	static inline function getInt(intToken:Token):Int {
		var int = Std.parseInt(intToken.text);
		if (int == null) throw "assert"; // should not happen I think?
		return int;
	}

	static function mkInt(originalToken:Token, newValue:Int):TExprKind {
		return TELiteral(TLInt(originalToken.with(TkDecimalInteger, Std.string(newValue))));
	}

	static function addOne(endValue:TExpr):TExpr {
		switch endValue.kind {
			case TELiteral(TLInt(intToken)):
				var int = getInt(intToken);
				return endValue.with(kind = mkInt(intToken, int + 1));
			case TEBinop(a, op = OpSub(_) | OpAdd(_), b = {kind: TELiteral(TLInt(intToken))}):
				var int = getInt(intToken);
				if (op.match(OpSub(_))) {
					int--;
				} else {
					int++;
				}
				if (int == 0) {
					return a; // TODO: keep trivia?
				} else {
					return endValue.with(kind = TEBinop(a, op, b.with(kind = mkInt(intToken, int))));
				}
			case _:
				return endValue.with(kind = TEBinop(endValue, opAdd, literalOne));
		}
	}

	function getSimpleSequence(f:TFor):Null<IntIterInfo> {
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
			case {kind: TEBinop({kind: TELocal(_, checkedVar)}, op = OpLt(_) | OpLte(_), b = {type: TTInt | TTUint})} if (checkedVar == originalLoopVar):
				if (isValidSimpleSequenceEndValueExpr(b, f.body)) {
					isReverse = false;
					endValue = b;
					if (op.match(OpLte(_))) {
						endValue = addOne(endValue);
					}
				} else {
					return null;
				}

			case {kind: TEBinop({kind: TELocal(_, checkedVar)}, op = OpGte(_) | OpGt(_), b = {type: TTInt | TTUint})} if (checkedVar == originalLoopVar):
				if (isValidSimpleSequenceEndValueExpr(b, f.body)) {
					isReverse = true;
					endValue = b;
					if (op.match(OpGt(_))) {
						endValue = addOne(endValue);
					}
				} else {
					return null;
				}

			case _:
				return null;
		}

		if (!isReverse) {
			switch f.eincr {
				case {kind: TEPreUnop(PreIncr(_), {kind: TELocal(_, checkedVar)})} if (checkedVar == originalLoopVar):
				case {kind: TEPostUnop({kind: TELocal(_, checkedVar)}, PostIncr(_))} if (checkedVar == originalLoopVar):
				case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpAssignOp(AOpAdd(_)), {kind: TELiteral(TLInt({text: "1"}))})} if (checkedVar == originalLoopVar):
				case _:
					return null;
			}
		} else {
			switch f.eincr {
				case {kind: TEPreUnop(PreDecr(_), {kind: TELocal(_, checkedVar)})} if (checkedVar == originalLoopVar):
				case {kind: TEPostUnop({kind: TELocal(_, checkedVar)}, PostDecr(_))} if (checkedVar == originalLoopVar):
				case {kind: TEBinop({kind: TELocal(_, checkedVar)}, OpAssignOp(AOpSub(_)), {kind: TELiteral(TLInt({text: "1"}))})} if (checkedVar == originalLoopVar):
				case _:
					return null;
			}

			startValue = addOne(startValue);
		}

		var iterator;
		if (isReverse) {
			var trail = removeTrailingTrivia(startValue);
			if (containsOnlyWhitespace(trail)) trail.resize(0);
			iterator = addParens(mk(TEHaxeIntIter(endValue, startValue), TTBuiltin, TTBuiltin));
			iterator = mk(TEField({kind: TOExplicit(mkDot(), iterator), type: iterator.type}, "reverse", mkIdent("reverse")), TTBuiltin, TTBuiltin);
			iterator = mkCall(iterator, [], TTBuiltin, trail);
			context.addToplevelImport("ReverseIntIterator", Using);
		} else {
			iterator = mk(TEHaxeIntIter(startValue, endValue), TTBuiltin, TTBuiltin);
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
		function loop(e:TExpr) {
			switch e.kind {
				case TEBinop({kind: TELocal(_, modifiedVar)}, OpAssign(_) | OpAssignOp(_), _)
				   | TEPreUnop(PreIncr(_) | PreDecr(_), {kind: TELocal(_, modifiedVar)})
				   | TEPostUnop({kind: TELocal(_, modifiedVar)}, PostIncr(_) | PostDecr(_))
				   if (modifiedVar == v):
					result = true;
				case _:
					iterExpr(loop, e); // TODO: add early exit option to iterExpr
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
