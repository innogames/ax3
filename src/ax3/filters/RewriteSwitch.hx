package ax3.filters;

class RewriteSwitch extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TESwitch(s):
				var newCases:Array<TSwitchCase> = [];
				var valueAcc = [];

				function processCaseBody(block:Array<TBlockExpr>, allowNonTerminalLast:Bool) {
					switch block {
						case [{expr: {kind: TEBlock(b)}}]: block = b.exprs; // for cases with "braced" body: `case value: {...}`
						case _:
					}

					if (block.length == 0) return; // empty block - nothing to do here

					var lastExpr = block[block.length - 1].expr;
					switch lastExpr.kind {
						case TEBreak(_): block.pop(); // TODO: move trivia to the previous one
						case TEReturn(_) | TEContinue(_) | TEThrow(_): // allowed terminators
						case _:
							if (!allowNonTerminalLast) {
								reportError(exprPos(lastExpr), "Non-terminal expression inside a switch case, possible fall-through?");
							}
					}
				}

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
							}, expr);
							processTrailingToken(function(t) {
								t.trailTrivia = t.trailTrivia.concat(v.syntax.colon.leadTrivia).concat(v.syntax.colon.trailTrivia);
							}, expr);
							values.push(expr);
						}

						processCaseBody(c.body, false);

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

				if (s.def != null) processCaseBody(s.def.body, true);

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
