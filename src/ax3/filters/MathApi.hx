package ax3.filters;

class MathApi extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall(
					eMethod = {
						kind: TEField(
							fieldObj = {kind: TOExplicit(_,
								{kind: TEDeclRef(_, {kind: TDClassOrInterface({name: "Math", parentModule: {parentPack: {name: ""}}})}) }
							)},
							fieldName = "round" | "floor" | "ceil",
							fieldToken)
					},
					args
				):

				args = mapCallArgs(processExpr, args);

				if (e.expectedType.match(TTInt | TTUint)) {
					e.with(type = TTInt);
				} else {
					fieldName = "f" + fieldName;
					fieldToken = mkIdent(fieldName, fieldToken.leadTrivia, fieldToken.trailTrivia);
					eMethod = eMethod.with(kind = TEField(fieldObj, fieldName, fieldToken));
					e.with(kind = TECall(eMethod, args));
				}

			case TEDeclRef(_, {name: "Infinity", kind: TDVar({parentModule: {parentPack: {name: ""}}})}):
				var name = "Math.POSITIVE_INFINITY";
				e.with(kind = TEBuiltin(mkIdent(name, removeLeadingTrivia(e), removeTrailingTrivia(e)), name));

			case TEPreUnop(PreNeg(_), {kind: TEDeclRef(_, {name: "Infinity", kind: TDVar({parentModule: {parentPack: {name: ""}}})})}):
				var name = "Math.NEGATIVE_INFINITY";
				e.with(kind = TEBuiltin(mkIdent(name, removeLeadingTrivia(e), removeTrailingTrivia(e)), name));

			case _:
				mapExpr(processExpr, e);
		}
	}
}
