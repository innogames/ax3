package ax3.filters;

import ax3.TypedTreeTools.tUntypedObject;

class RewriteArrayAccess extends AbstractFilter {
	static final eGetProperty = mkBuiltin("Reflect.getProperty", TTFun([tUntypedObject, TTString], TTAny));
	static final eSetProperty = mkBuiltin("Reflect.setProperty", TTFun([tUntypedObject, TTString, TTAny], TTVoid));

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEArrayAccess(a):
				var eobj = processExpr(a.eobj);
				var eindex = processExpr(a.eindex);

				switch [eobj.type, eindex.type] {
					case [TTArray(_), TTInt | TTUint]:
						e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));

					case [TTArray(_), _]:
						// reportError(exprPos(e), "Non-int array access for Array");

						e.with(kind = TEArrayAccess({
							syntax: a.syntax,
							eobj: eobj.with(kind = TEHaxeRetype(eobj), type = TTAny),
							eindex: eindex.with(expectedType = TTString)
						}));

					case [TTDictionary(expectedKeyType, _), keyType]:
						if (expectedKeyType != TTAny && keyType != TTAny && !Type.enumEq(expectedKeyType, keyType)) {
							reportError(exprPos(e), 'Invalid dictionary key type, expected $expectedKeyType, got $keyType');
						}
						e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));

					case _:
						mapExpr(processExpr, e);
				}

			case _:
				mapExpr(processExpr, e);
		}
	}

}