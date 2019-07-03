package ax3.filters;

// TODO: rewrite `default` to `case _`?
class RewriteSwitch extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TESwitch(s):
				var newCases:Array<TSwitchCase> = [];
				var valueAcc = [];

				function processCaseBody(block:Array<TBlockExpr>, allowNonTerminalLast:Bool):Array<Trivia> {
					switch block {
						case [{expr: {kind: TEBlock(b)}}]:  block = b.exprs; // for cases with "braced" body: `case value: {...}`
						case _:
					}

					if (block.length == 0) return []; // empty block - nothing to do here

					var lastExpr = block[block.length - 1].expr;
					switch lastExpr.kind {
						case TEBreak(breakToken):
							var blockExpr = block.pop();
							var trivia = breakToken.leadTrivia.concat(breakToken.trailTrivia);
							if (blockExpr.semicolon != null) {
								trivia = trivia.concat(blockExpr.semicolon.leadTrivia).concat(blockExpr.semicolon.trailTrivia);
							}
							return trivia;

						case TEReturn(_) | TEContinue(_) | TEThrow(_): // allowed terminators
							return [];

						case _:
							if (!allowNonTerminalLast) {
								throwError(exprPos(lastExpr), "Non-terminal expression inside a switch case, possible fall-through?");
							}
							return [];
					}
				}

				for (i in 0...s.cases.length) {
					var c = s.cases[i];
					var value = switch c.values {
						case [value]: value;
						case _: throw "assert";
					};
					valueAcc.push({syntax: c.syntax, value: value});
					if (c.body.length > 0) {
						var values = [];
						for (v in valueAcc) {
							var expr = v.value;
							processLeadingToken(function(t) {
								t.leadTrivia = t.leadTrivia.concat(v.syntax.keyword.leadTrivia);
							}, expr);
							processTrailingToken(function(t) {
								t.trailTrivia = t.trailTrivia.concat(v.syntax.colon.leadTrivia).concat(v.syntax.colon.trailTrivia);
							}, expr);
							values.push(expr);
						}

						var isLast = (i == s.cases.length - 1) && s.def == null;

						var breakTrivia = processCaseBody(c.body, isLast);

						var colonTrivia = removeTrailingTrivia(values[values.length - 1]);
						if (breakTrivia.length > 0) {
							if (c.body.length == 0) {
								colonTrivia = colonTrivia.concat(breakTrivia);
							} else {
								var lastBlockExpr = c.body[c.body.length - 1];
								if (lastBlockExpr.semicolon != null) {
									lastBlockExpr.semicolon.trailTrivia = lastBlockExpr.semicolon.trailTrivia.concat(breakTrivia);
								} else {
									processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(breakTrivia), lastBlockExpr.expr);
								}
							}
						}

						newCases.push({
							syntax: {
								keyword: new Token(0, TkIdent, "case", removeLeadingTrivia(values[0]), [whitespace]),
								colon: new Token(0, TkColon, ":", [], colonTrivia)
							},
							values: values,
							body: c.body // mutated inplace
						});
						valueAcc = [];
					}
				}

				if (s.def != null) {
					processCaseBody(s.def.body, true);
				}

				e.with(kind = TESwitch({
					syntax: s.syntax,
					subj: s.subj,
					cases: newCases,
					def: s.def
				}));

			case _:
				e;
		}
	}
}
