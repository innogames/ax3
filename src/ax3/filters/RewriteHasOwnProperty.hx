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
								// TODO: ASAny.___hasOwnProperty?
								e;

							case TTInst(_):
								reportError(exprPos(e), "hasOwnProperty on class instance detected");
								// TODO: (obj : ASAny).___hasOwnProperty?
								e;

							case _:
								throwError(exprPos(e), "Unsupported hasOwnProperty call");
						}
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