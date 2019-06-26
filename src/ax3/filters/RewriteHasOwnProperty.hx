package ax3.filters;

class RewriteHasOwnProperty extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall(eField = {kind: TEField(obj, "hasOwnProperty", fieldToken)}, args):
				switch obj.kind {
					case TOExplicit(dot, eobj):
						eobj = mapExpr(processExpr, eobj);
						args = mapCallArgs(processExpr, args);

						switch eobj.type {
							case TTDictionary(_, _):
								e.with(kind = TECall(
									eField.with(kind = TEField(
										obj.with(kind = TOExplicit(dot, eobj)),
										"exists",
										new Token(0, TkIdent, "exists", fieldToken.leadTrivia, fieldToken.trailTrivia)
									)),
									args
								));

							case TTObject(_) | TTAny:
								reportError(exprPos(e), "untyped hasOwnProperty detected");
								e.with(kind = TECall(
									eField.with(kind = TEField(obj.with(kind = TOExplicit(dot, eobj)), "hasOwnProperty", fieldToken)),
									args
								));

							case TTInst(_):
								reportError(exprPos(e), "hasOwnProperty on class instance detected");
								e.with(kind = TECall(
									eField.with(kind = TEField(
										obj.with(kind = TOExplicit(dot, eobj.with(kind = TEHaxeRetype(eobj), type = TTAny))),
										"hasOwnProperty",
										fieldToken
									)),
									args
								));

							case _:
								throwError(exprPos(e), "Unsupported hasOwnProperty call");
						}

					case TOImplicitThis(cls):
						reportError(exprPos(e), "hasOwnProperty on class instance detected");
						var eThis = mk(TELiteral(TLThis(mkIdent("this", fieldToken.leadTrivia, []))), obj.type, obj.type);
						fieldToken.leadTrivia = [];
						args = mapCallArgs(processExpr, args);
						e.with(kind = TECall(
							eField.with(kind = TEField(
								obj.with(kind = TOExplicit(mkDot(), eThis.with(kind = TEHaxeRetype(eThis), type = TTAny))),
								"hasOwnProperty",
								fieldToken
							)),
							args
						));

					case _:
						throwError(exprPos(e), "Unsupported hasOwnProperty call");
				}

			case TEField(_, "hasOwnProperty", _):
				throwError(exprPos(e), "closure on hasOwnProperty?");

			case _:
				mapExpr(processExpr, e);
		}
	}
}