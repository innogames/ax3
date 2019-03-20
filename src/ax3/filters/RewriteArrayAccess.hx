package ax3.filters;

class RewriteArrayAccess extends AbstractFilter {
	static final eGetProperty = mkBuiltin("Reflect.getProperty", TTFun([TTObject, TTString], TTAny));
	static final eSetProperty = mkBuiltin("Reflect.setProperty", TTFun([TTObject, TTString, TTAny], TTVoid));

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEArrayAccess(a):
				var eobj = processExpr(a.eobj);
				var eindex = processExpr(a.eindex);

				switch [a.eobj.type, a.eindex.type] {
					case [TTArray(_), TTInt | TTUint]:
						e;

					case [TTArray(_), _]:
						// reportError(exprPos(e), "Non-int array access for Array");
						e;

					case _:
						e;
				}

			case TEBinop(ea = {kind: TEArrayAccess(a)}, op = OpAssign(_) | OpAssignOp(_), eb):
				var eobj = processExpr(a.eobj);
				var eindex = processExpr(a.eindex);

				e;

			case _:
				mapExpr(processExpr, e);
		}
	}

}