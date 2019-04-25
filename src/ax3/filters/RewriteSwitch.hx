package ax3.filters;

class RewriteSwitch extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TESwitch(s):
				var newCases:Array<TSwitchCase> = [];
				var valueAcc = [];
				var nullCase = null; // workaround for https://github.com/HaxeFoundation/haxe/issues/8213

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
								throw "assert";
							}
					}
				}

				for (i in 0...s.cases.length) {
					var c = s.cases[i];
					var value = switch c.values {
						case [value]:
							if (value.kind.match(TELiteral(TLNull(_)))) {
								nullCase = c;
							}
							value;
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
						processCaseBody(c.body, isLast);

						newCases.push({
							syntax: {
								keyword: new Token(0, TkIdent, "case", removeLeadingTrivia(values[0]), [whitespace]),
								colon: new Token(0, TkColon, ":", [], removeTrailingTrivia(values[values.length - 1]))
							},
							values: values,
							body: c.body // mutated inplace
						});
						valueAcc = [];
					}
				}

				if (s.def != null) {
					processCaseBody(s.def.body, true);
				} else if (nullCase != null) {
					// have to add a default case if `case null` is there to workaround https://github.com/HaxeFoundation/haxe/issues/8213
					s.def = {
						syntax: {
							keyword: mkIdent("default", nullCase.syntax.keyword.leadTrivia.copy()),
							colon: new Token(0, TkColon, ":", [], [
								whitespace,
								new Trivia(TrLineComment, "// workaround for https://github.com/HaxeFoundation/haxe/issues/8213"),
								newline,
							]),
						},
						body: []
					}
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
