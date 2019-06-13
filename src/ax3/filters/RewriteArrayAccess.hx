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
					case [TTArray(_) | TTVector(_) | TTXMLList | TTInst({name: "ByteArray", parentModule: {parentPack: {name: "flash.utils"}}}), TTInt | TTUint | TTNumber]
					   | [TTObject(_), _]
					   :
						if (eindex.type == TTNumber) reportError(exprPos(e), "Array access using Number index");
						e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));

					case [TTArray(_) | TTVector(_), _]:
						// reportError(exprPos(e), "Non-int array access for Array");

						e.with(kind = TEArrayAccess({
							syntax: a.syntax,
							eobj: eobj.with(kind = TEHaxeRetype(eobj), type = TTAny),
							eindex: eindex.with(expectedType = TTString)
						}));

					case [TTDictionary(expectedKeyType, _), keyType]:
						switch [expectedKeyType, keyType] {
							case [TTAny, _] | [_, TTAny]: // oh well
							case [TTObject(TTAny), _]:
							case [TTClass, TTStatic(_)]: //allowed
							case _:
								if (!Type.enumEq(expectedKeyType, keyType)) {
									reportError(exprPos(e), 'Invalid dictionary key type, expected $expectedKeyType, got $keyType');
								}
						}
						e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));

					case _:
						reportError(exprPos(e), "Dynamic array access?");
						eobj = eobj.with(kind = TEHaxeRetype(eobj), type = TTAny);
						e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));
				}

			case _:
				mapExpr(processExpr, e);
		}
	}

}