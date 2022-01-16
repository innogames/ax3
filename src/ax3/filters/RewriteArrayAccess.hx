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

					case [TTArray(_) | TTVector(_) | TTXMLList, TTInt | TTUint | TTNumber] | [TTObject(_), _]
					   :
						if (eindex.type == TTNumber) reportError(exprPos(e), "Array access using Number index");
						e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));

					case [TTInst({name: "ByteArray", parentModule: {parentPack: {name: "flash.utils"}}}), TTInt | TTUint | TTNumber]
					   :
						if (eindex.type == TTNumber) reportError(exprPos(e), "ByteArray access using Number index");
						e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)), type = TTUint);

					case [TTArray(_), TTString]:
						reportError(exprPos(e), "String index used for array access on Array. Did you mean to use Dictionary/Object? Falling back to reflection.");
						e.with(kind = TEArrayAccess({
							syntax: a.syntax,
							eobj: eobj.with(kind = TEHaxeRetype(eobj), type = TTAny),
							eindex: eindex
						}));

					case [TTVector(_), TTString]:
						throwError(exprPos(e), "String index used for array access on Vector. Reflection doesn't currently work consistently on this");
						// e.with(kind = TEArrayAccess({
						// 	syntax: a.syntax,
						// 	eobj: eobj.with(kind = TEHaxeRetype(eobj), type = TTAny),
						// 	eindex: eindex
						// }));

					case [TTArray(_) | TTVector(_), _]:
						reportError(exprPos(e), "Non-integer index used for array access on Array/Vector, coercing to Int");
						e.with(kind = TEArrayAccess({
							syntax: a.syntax,
							eobj: eobj,
							eindex: eindex.with(expectedType = TTInt)
						}));

					case [TTDictionary(expectedKeyType, _), keyType]:
						switch [expectedKeyType, keyType] {
							case [TTAny, _] | [_, TTAny]: // oh well
							case [TTObject(TTAny), _]:
							case [TTClass, TTStatic(_)]: //allowed
							case _:
								if (!typeEq(expectedKeyType, keyType)) {
									reportError(exprPos(e), 'Invalid dictionary key type, expected $expectedKeyType, got $keyType');
								}
						}
						e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));

					case _:
						reportError(exprPos(e), "Dynamic array access?");
						if (!eobj.type.match(TTAny)) {
							eobj = eobj.with(kind = TEHaxeRetype(eobj), type = TTAny);
						}
						e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));
				}

			case _:
				mapExpr(processExpr, e);
		}
	}

}