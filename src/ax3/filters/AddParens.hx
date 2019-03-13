package ax3.filters;

class AddParens {
	public static function process(e:TExpr):TExpr {
		e = mapExpr(process, e);
		return switch e.kind {
			case TELocal(_) | TELiteral(_) | TEBlock(_):
				e;
			case _:
				return addParens(e);
		}
	}
}
