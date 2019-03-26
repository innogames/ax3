package ax3.filters;

class RewriteNewArray extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TENew(keyword, {kind: TEBuiltin(_, "Array")}, args) if (args.args.length > 0):
				switch args.args {
					case [{expr: {type: TTInt | TTUint | TTNumber}}]:
						// array of some length
						e.with(kind = TECall(
							mkBuiltin("ASCompat.allocArray", TTFunction, keyword.leadTrivia),
							args
						));
					case _:
						// array initializer
						e.with(kind = TEArrayDecl({
							syntax: {
								openBracket: new Token(0, TkBracketOpen, "[", keyword.leadTrivia, args.openParen.trailTrivia),
								closeBracket: new Token(0, TkBraceClose, "]", args.closeParen.leadTrivia, args.closeParen.trailTrivia),
							},
							elements: args.args
						}));
				}
			case _:
				mapExpr(processExpr, e);
		}
	}
}