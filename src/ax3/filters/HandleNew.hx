package ax3.filters;

class HandleNew extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TENew(keyword, eclass, args):
				switch eclass.kind {
					case TEDeclRef(_, {kind: TDClassOrInterface(c)}): // just a class instantiation, nothing to rewrite, but mark the class for constructor injection
						// c.wasInstantiated = true; TODO
						e;

					case TEBuiltin(_) | TEVector(_): // other kinds of typed `new` - nothing to do
						e;

					case _: // anything else - rewrite to Type.createInstance
						var leadTrivia = keyword.leadTrivia;
						var trailTrivia = removeTrailingTrivia(e);

						var eCreateInstance = mk(TEBuiltin(new Token(0, TkIdent, "Type.createInstance", leadTrivia, []), "Type.createInstance"), TTBuiltin, TTBuiltin);
						var ctorArgs = if (args != null) args.args else [];

						e.with(kind = TECall(eCreateInstance, {
							openParen: mkOpenParen(),
							args: [
								{expr: eclass, comma: commaWithSpace},
								{
									expr: mk(TEArrayDecl({
										syntax: {
											openBracket: mkOpenBracket(),
											closeBracket: mkCloseBracket()
										},
										elements: ctorArgs
									}), tUntypedArray, tUntypedArray),
									comma: null
								}
							],
							closeParen: new Token(0, TkParenClose, ")", [], trailTrivia)
						}));
				}
			case _:
				e;
		}
	}
}