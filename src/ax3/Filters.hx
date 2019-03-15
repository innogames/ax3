package ax3;

import ax3.TypedTree;
import ax3.Structure;
import ax3.filters.*;

class Filters {
	static function processClass(f:TExpr->TExpr, c:TClassDecl) {
		for (m in c.members) {
			switch (m) {
				case TMField(field):
					switch (field.kind) {
						case TFVar(v): processVars(f, v.vars);
						case TFFun(field): processFunction(f, field.fun);
						case TFGetter(field) | TFSetter(field): processFunction(f, field.fun);
					}
				case TMStaticInit(i): i.expr = f(i.expr);
				case TMUseNamespace(_):
				case TMCondCompBegin(_):
				case TMCondCompEnd(_):
			}
		}
	}

	static function processVars(f:TExpr->TExpr, vars:Array<TVarFieldDecl>) {
		for (v in vars) {
			if (v.init != null) {
				v.init.expr = f(v.init.expr);
			}
		}
	}

	static function processFunction(f:TExpr->TExpr, fun:TFunction) {
		fun.expr = f(fun.expr);
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

	static function runFilter(f:TExpr->TExpr, modules:Array<TModule>) {
		for (mod in modules) {
			processDecl(f, mod.pack.decl);
			for (decl in mod.privateDecls) {
				processDecl(f, decl);
			}
		}
	}

	public static function run(context:Context, structure:Structure, modules:Array<TModule>) {
		for (f in [
			new AddParens(context),
			// new CoerceToBool(context),
			// new RestArgs(),
			// new AddRequiredParens(context),
		]) {
			f.run(modules);
		}
	}
}
