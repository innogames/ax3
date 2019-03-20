package ax3.filters;

class CheckExpectedTypes extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		switch [e.expectedType, e.type] {
			case [TTAny | TTVoid, _]: // we don't care here
			case [TTNumber, TTInt | TTUint]: // or here
			case [expected, actual]:
				if (actual != expected) {
					reportError(exprPos(e), 'Missing type coercion: expected=${expected.getName()}, actual=${actual.getName()}');
				}
		}
		return e;
	}
}
