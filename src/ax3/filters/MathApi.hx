package ax3.filters;

class MathApi extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECall(eMethod = {kind: TEField(fieldObj = {kind: TOExplicit(_, eMath)}, fieldName = "round" | "floor" | "ceil", fieldToken)}, args) if (isMathClassRef(eMath)):
				if (e.expectedType.match(TTInt | TTUint)) {
					e.with(type = TTInt);
				} else {
					fieldName = "f" + fieldName;
					fieldToken = mkIdent(fieldName, fieldToken.leadTrivia, fieldToken.trailTrivia);
					eMethod = eMethod.with(kind = TEField(fieldObj, fieldName, fieldToken));
					e.with(kind = TECall(eMethod, args));
				}
			case _:
				e;
		}
	}

	static function isMathClassRef(e:TExpr):Bool {
		return e.kind.match(TEDeclRef(_, {kind: TDClassOrInterface({name: "Math", parentModule: {parentPack: {name: ""}}})}));
	}
}
