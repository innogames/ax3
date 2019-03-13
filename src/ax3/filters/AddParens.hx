package ax3.filters;

class AddParens {
	public static function process(e:TExpr):TExpr {
		e = mapExpr(process, e);
		return switch (e.kind) {
			case TELocal(_) | TELiteral(_):
				e;
			case _:
				var o = new Token(0, TkParenOpen, "(", removeLeadingTrivia(e), []);
				var c = new Token(0, TkParenClose, ")", [], removeTrailingTrivia(e));
				mk(TEParens(o, e, c), e.type);
		}
	}
}
