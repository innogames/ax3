package ax3.filters;

class AddSuperCtorCall extends AbstractFilter {
	override function processDecl(c:TDecl) {
		switch c.kind {
			case TDClassOrInterface(c = {kind: TClass(info)}) if (info.extend != null): // class with a parent class
				for (m in c.members) {
					switch (m) {
						case TMField({kind: TFFun(f)}) if (f.name == c.name): // constructor \o/
							f.fun.expr = processCtorExpr(f.fun.expr, info.extend.superClass);
							break;
						case _:
					}
				}
			case _:
		}
	}

	function processCtorExpr(e:TExpr, superClass:TClassOrInterfaceDecl):TExpr {
		if (hasSuperCall(e)) {
			return e;
		} else {
			// TODO
			// superClass.wasInstantiated = true; // generate empty ctor if required (TODO: we should actually skip generating `super()` if there are no ctors in the whole chain)
			var tSuper = TTInst(superClass);
			var eSuper = mk(TELiteral(TLSuper(mkIdent("super"))), tSuper, tSuper);
			var eSuperCall = mkCall(eSuper, [], TTVoid);
			return concatExprs(eSuperCall, e);
		}
	}

	function hasSuperCall(e:TExpr):Bool {
		switch e.kind {
			case TEParens(_, e, _):
				return hasSuperCall(e);

			case TECall({kind: TELiteral(TLSuper(_))}, _):
				return true;

			case TEBlock(block):
				for (e in block.exprs) {
					if (hasSuperCall(e.expr)) {
						return true;
					}
				}
				return false;

			case _:
				return false;
		}
	}
}
