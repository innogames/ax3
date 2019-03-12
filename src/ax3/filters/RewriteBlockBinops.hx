package ax3.filters;

/**
	Replace block-level `something && doSomething()` expressions with `if (something) doSomething()`.
**/
class RewriteBlockBinops {
	public static function process(e:TExpr):TExpr {
		e = mapExpr(process, e);

		return switch e.kind {
			case TEBlock(b):
				e.with(
					kind = TEBlock(b.with(
						exprs = [for (e in b.exprs) e.with(expr = modifyBlockExpr(e.expr))]
					)
				));
			case _:
				e;
		}
	}

	static function modifyBlockExpr(be:TExpr):TExpr {
		var check = extract(be);
		if (check == null) {
			// not `a && b`, nothing to modify
			return be;
		}

		// remove parens, extract leading/trailing trivia
		var cond, lead, trail;
		switch check.check.kind {
			case TEParens(openParen, e, closeParen):
				cond = e;
				lead = openParen.leadTrivia.concat(openParen.trailTrivia);
				trail = closeParen.leadTrivia.concat(closeParen.trailTrivia);
			case _:
				cond = check.check;
				lead = removeLeadingTrivia(check.check);
				trail = removeTrailingTrivia(check.check);
		};

		// include trivia around `&&` into the trailing trivia of the closing paren
		trail = trail.concat(check.andToken.leadTrivia).concat(check.andToken.trailTrivia);

		// normalize whitespace after `)`: change any number of whitespace to a single space, otherwise leave unchanged
		if (trail.length == 0 || containsOnlyWhitespace(trail)) {
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
		}), TTVoid);
	}

	/** for `e1 && e2` returns `{check: e1, action: e2}` otherwise returns `null` **/
	static function extract(e:TExpr):Null<{check:TExpr, action:TExpr, andToken:Token}> {
		return switch (e.kind) {
			case TEBinop(a, op = OpAnd(t), b):
				var more = extract(b); // see if there was more chained `&&`
				if (more == null) {
					{
						check: a,
						action: b,
						andToken: t,
					};
				} else {
					{
						check: e.with(kind = TEBinop(a, op, more.check)),
						action: more.action,
						andToken: more.andToken,
					};
				}
			case _:
				null;
		}
	}
}