package ax3.filters;

/**
	Replace block-level `something && doSomething()` expressions with `if (something) doSomething()`.
**/
class RewriteBlockBinops extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBlock(b):
				var mapped = mapBlock(modifyBlockExpr, b);
				if (mapped == b) e else e.with(kind = TEBlock(mapped));

			case TESwitch(s):
				// we modify the expr in-place here, but oh well
				for (c in s.cases) {
					c.body = mapBlockExprs(modifyBlockExpr, c.body);
				}
				if (s.def != null) {
					s.def.body = mapBlockExprs(modifyBlockExpr, s.def.body);
				}
				e;

			case _:
				e;
		}
	}

	// sorry, this code below is (unnecessarily) complex because we want to handle trivia...
	static function extractExprFromParens(e:TExpr) {
		return switch e.kind {
			case TEParens(openParen, e, closeParen):
				{
					expr: e,
					lead: () -> openParen.leadTrivia.concat(openParen.trailTrivia),
					tail: () -> closeParen.leadTrivia.concat(closeParen.trailTrivia)
				}
			case _:
				{
					expr: e,
					lead: () -> removeLeadingTrivia(e),
					tail: () -> removeTrailingTrivia(e)
				}
		};
	}

	static function modifyBlockExpr(be:TExpr):TExpr {

		var e = extractExprFromParens(be);
		var check = extract(e.expr);
		if (check == null) {
			// not `a && b`, nothing to modify
			return be;
		}

		var lead = e.lead(), trail = e.tail();

		// remove parens, extract leading/trailing trivia
		var cond;
		{
			var e = extractExprFromParens(check.check);
			cond = e.expr;
			lead = lead.concat(e.lead());
			trail = trail.concat(e.tail());
		}

		// include trivia around `&&` into the trailing trivia of the closing paren
		trail = trail.concat(check.andToken.leadTrivia).concat(check.andToken.trailTrivia);

		// normalize whitespace after `)`: change any number of whitespace to a single space, otherwise leave unchanged
		if (trail.length == 0 || containsOnlyWhitespace(trail)) {
			// TODO: if it's a newline, then we should keep it
			trail = [new Trivia(TrWhitespace, " ")];
		}

		// construct an `if (check) action` expression
		return mk(TEIf({
			syntax: {
				keyword: new Token(0, TkIdent, "if", lead, [new Trivia(TrWhitespace, " ")]),
				openParen: new Token(0, TkParenOpen, "(", [], []),
				closeParen: new Token(0, TkParenClose, ")", [], trail)
			},
			econd: cond,
			ethen: check.action,
			eelse: null,
		}), TTVoid, TTVoid);
	}

	/** for `e1 && e2` returns `{check: e1, action: e2}` otherwise returns `null` **/
	static function extract(e:TExpr):Null<{check:TExpr, action:TExpr, andToken:Token}> {
		inline function toBool(e:TExpr):TExpr {
			return if (e.expectedType == TTBoolean) e else e.with(expectedType = TTBoolean);
		}

		return switch (e.kind) {
			case TEBinop(a, op = OpAnd(t), b):
				var more = extract(a); // see if there was more chained `&&`
				if (more == null) {
					{
						check: toBool(a),
						action: b,
						andToken: t,
					};
				} else {
					{
						check: mk(TEBinop(more.check, OpAnd(more.andToken), toBool(more.action)), TTBoolean, TTBoolean),
						action: b,
						andToken: t,
					};
				}
			case _:
				null;
		}
	}
}