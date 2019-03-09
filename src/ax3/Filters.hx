package ax3;

import ax3.TypedTree;
import ax3.TypedTreeTools.mapExpr;
import ax3.Structure;
using ax3.WithMacro;

class Filters {

	static function f2(e:TExpr):TExpr {
		return switch (e.kind) {
			case TEIf(i):
				switch (i.econd.type) {
					case TTBoolean:
						e;
					case _:
						i = i.with(
							econd = {kind: TELiteral(TLString(new Token(TkStringDouble, '"TODO"', [], []))), type: TTBoolean},
							ethen = i.ethen,
							eelse = i.eelse
						);
						e.with(kind = TEIf(i));
				}

			case _:
				mapExpr(f2, e);
		}
	}


	static function processClass(f:TExpr->TExpr, c:TClassDecl) {
		for (m in c.members) {
			switch (m) {
				case TMField(field):
					switch (field.kind) {
						case TFVar(v): processVars(f, v.vars);
						case TFFun(field): processFunction(f, field.fun);
						case TFGetter(field) | TFSetter(field): processFunction(f, field.fun);
					}
				case TMStaticInit(b): processBlock(f, b);
				case TMUseNamespace(_):
				case TMCondCompBegin(_):
				case TMCondCompEnd(_):
			}
		}
	}

	static function processVars(f:TExpr->TExpr, vars:Array<TVarFieldDecl>) {
		for (v in vars) {
			if (v.init != null) {
				v.init.expr = mapExpr(f, v.init.expr);
			}
		}
	}

	static function processFunction(f:TExpr->TExpr, fun:TFunction) {
		processBlock(f, fun.block);
	}

	static function processBlock(f:TExpr->TExpr, b:TBlock) {
		for (i in 0...b.exprs.length) {
			b.exprs[i].expr = f(b.exprs[i].expr);
		}
	}

	static function processDecl(f:TExpr->TExpr, decl:TDecl) {
		switch (decl) {
			case TDClass(c): processClass(f, c);
			case TDVar(v): processVars(f, v.vars);
			case TDFunction(fun): processFunction(f, fun.fun);
			case TDInterface(_):
			case TDNamespace(_):
		}
	}

	public static function run(structure:Structure, modules:Array<TModule>) {
		for (mod in modules) {
			processDecl(f2, mod.pack.decl);
			for (decl in mod.privateDecls) {
				processDecl(f2, decl);
			}
		}
	}
}
