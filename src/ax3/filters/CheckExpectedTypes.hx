package ax3.filters;

class CheckExpectedTypes extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		if (e.type != e.expectedType) {
			reportError(exprPos(e), 'Missing type coercion: expected=${e.expectedType.getName()}, actual=${e.type.getName()}');
		}
		return e;
	}
}
