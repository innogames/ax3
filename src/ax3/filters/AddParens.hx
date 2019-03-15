package ax3.filters;

class AddParens extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TELocal(_) | TELiteral(_) | TEBlock(_) | TEDeclRef(_):
				e;
			case _:
				return addParens(e);
		}
	}
}
