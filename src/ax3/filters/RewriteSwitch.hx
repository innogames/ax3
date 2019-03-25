package ax3.filters;

class RewriteSwitch extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TESwitch(s):
				var newCases:Array<TSwitchCase> = [];
				var valueAcc = [];
				for (c in s.cases) {
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
								t.trailTrivia = t.trailTrivia.concat(v.syntax.colon.leadTrivia).concat(v.syntax.colon.trailTrivia);
							}, expr);
							values.push(expr);
						}

						var block = c.body;
						switch block {
							case [{expr: {kind: TEBlock(b)}}]: block = b.exprs;
							case _:
						}

						var lastExpr = block[block.length - 1].expr;
						switch lastExpr.kind {
							case TEBreak(_): block.pop(); // TODO: move trivia to the previous one
							case TEReturn(_) | TEContinue(_) | TEThrow(_): // allowed terminators
							case _:
								reportError(exprPos(lastExpr), "Non-terminal expression inside a switch case, possible fall-through?");
						}

						// TODO: something is reall wrong with trivia here
						newCases.push({
							syntax: {
								keyword: new Token(0, TkIdent, "case", removeLeadingTrivia(values[0]), [mkWhitespace()]),
								colon: new Token(0, TkColon, ":", [], removeTrailingTrivia(values[values.length - 1]))
							},
							values: values,
							body: c.body // mutated inplace
						});
						valueAcc = [];
					}
				}

				var newDef = s.def;

				e.with(kind = TESwitch({
					syntax: s.syntax,
					subj: s.subj,
					cases: newCases,
					def: newDef
				}));

			case _:
				e;
		}
	}
}
