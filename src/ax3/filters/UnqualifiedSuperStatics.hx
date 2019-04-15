package ax3.filters;

import ax3.ParseTree.DotPath;

/**
	Haxe only resolves unqualified static field access in the current class,
	while AS3 also looks up in parent classes. So this filter rewrites these
	cases into qualified access.
**/
class UnqualifiedSuperStatics extends AbstractFilter {
	var thisClass:Null<TClassOrInterfaceDecl>;
	override function processClass(c:TClassOrInterfaceDecl) {
		thisClass = c;
		super.processClass(c);
		thisClass = null;
	}

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEField({kind: TOImplicitClass(c), type: tSuperRef}, fieldName, fieldToken) if (c != thisClass):
				var leadTrivia = fieldToken.leadTrivia;
				fieldToken.leadTrivia = [];

				var dotPath:DotPath = {
					var parts = /* if (c.publicFQN != null) c.publicFQN.split(".") else */ [c.name]; // TODO: FQN
					{
						first: new Token(0, TkIdent, parts[0], leadTrivia, []),
						rest: [for (i in 1...parts.length) {sep: mkDot(), element: mkIdent(parts[i])}]
					};
				};

				var eSuperRef = mk(TEDeclRef(dotPath, {name: c.name, kind: TDClassOrInterface(c)}), tSuperRef, tSuperRef);

				e.with(kind = TEField({kind: TOExplicit(mkDot(), eSuperRef), type: tSuperRef}, fieldName, fieldToken));
			case _:
				mapExpr(processExpr, e);
		}
	}
}
