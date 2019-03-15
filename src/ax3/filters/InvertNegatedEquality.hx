package ax3.filters;

class InvertNegatedEquality extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch (e.kind) {
			case TEPreUnop(PreNot(notToken), e2):
				switch (e2.kind) {
					// TODO: add trivia from notToken to `a` expr
					case TEBinop(a, OpEquals(t), b):
						var t = new Token(t.pos, TkExclamationEquals, "!=", t.leadTrivia, t.trailTrivia);
						e.with(kind = TEBinop(a, OpNotEquals(t), b));
					case TEBinop(a, OpNotEquals(t), b):
						var t = new Token(t.pos, TkEqualsEquals, "==", t.leadTrivia, t.trailTrivia);
						e.with(kind = TEBinop(a, OpEquals(t), b));
					case _:
						e;
				}
			case _:
				e;
		}
	}
}
