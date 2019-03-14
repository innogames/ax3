package ax3.filters;

class AbstractFilter {
	public function new() {}

	public function run(modules:Array<TModule>) {
		for (mod in modules) {
			processDecl(mod.pack.decl);
			for (decl in mod.privateDecls) {
				processDecl(decl);
			}
		}
	}

	function processDecl(decl:TDecl) {
		switch (decl) {
			case TDClass(c): processClass(c);
			case TDVar(v): processVarFields(v.vars);
			case TDFunction(fun): processFunction(fun.fun);
			case TDInterface(i): processInterface(i);
			case TDNamespace(_):
		}
	}

	function processClass(c:TClassDecl) {
		for (m in c.members) {
			switch (m) {
				case TMField(field):
					switch (field.kind) {
						case TFVar(v): processVarFields(v.vars);
						case TFFun(field): processFunction(field.fun);
						case TFGetter(field) | TFSetter(field): processFunction(field.fun);
					}
				case TMStaticInit(i): i.expr = processExpr(i.expr);
				case TMUseNamespace(_):
				case TMCondCompBegin(_):
				case TMCondCompEnd(_):
			}
		}
	}

	function processInterface(i:TInterfaceDecl) {
		for (m in i.members) {
			switch (m) {
				case TIMField(field):
					switch (field.kind) {
						case TIFFun(field): processSignature(field.sig);
						case TIFGetter(_) | TIFSetter(_):
					}
				case TIMCondCompBegin(_):
				case TIMCondCompEnd(_):
			}
		}
	}

	function processFunction(fun:TFunction) {
		fun.sig = processSignature(fun.sig);
		fun.expr = processExpr(fun.expr);
	}

	function processSignature(sig:TFunctionSignature) {
		return sig;
	}

	function processExpr(e:TExpr):TExpr {
		return e;
	}

	function processVarFields(vars:Array<TVarFieldDecl>) {
		for (v in vars) {
			if (v.init != null) {
				v.init.expr = processExpr(v.init.expr);
			}
		}
	}
}
