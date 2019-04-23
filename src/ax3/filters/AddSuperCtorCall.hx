package ax3.filters;

import ax3.TypedTreeTools.getConstructor;

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
		if (getConstructor(superClass) == null || hasSuperCall(e)) {
			return e;
		} else {
			var tSuper = TTInst(superClass);
			var eSuper = mk(TELiteral(TLSuper(mkIdent("super", getInnerIndent(e)))), tSuper, tSuper);
			var eSuperCall = mk(TECall(eSuper, {openParen: mkOpenParen(), args: [], closeParen: mkCloseParen()}), TTVoid, TTVoid);
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
