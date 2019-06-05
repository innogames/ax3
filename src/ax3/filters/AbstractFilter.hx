package ax3.filters;

class AbstractFilter {
	final context:Context;

	var currentPath:Null<String>;

	public function new(context) {
		this.context = context;
	}

	function reportError(pos:Int, msg:String) {
		context.reportError(currentPath, pos, msg);
	}

	inline function throwError(pos:Int, msg:String):Dynamic {
		context.reportError(currentPath, pos, msg);
		throw "assert"; // TODO do it nicer
	}

	function processModule(mod:TModule) {
		mod.pack.imports = [for (i in mod.pack.imports) if (processImport(i)) i]; // TODO: keep cond.compilation and trivia

		processDecl(mod.pack.decl);

		for (decl in mod.privateDecls) {
			processDecl(decl);
		}
	}

	public function run(tree:TypedTree) {
		for (pack in tree.packages) {
			for (mod in pack) {
				if (mod.isExtern) {
					continue;
				}
				currentPath = mod.path;
				processModule(mod);
				currentPath = null;
			}
		}
	}

	function processImport(i:TImport):Bool {
		return true;
	}

	function processDecl(decl:TDecl) {
		switch decl.kind {
			case TDClassOrInterface(c): processClass(c);
			case TDVar(v): processVarFields(v.vars);
			case TDFunction(fun): processFunction(fun.fun);
			case TDNamespace(_):
		}
	}

	function processClass(c:TClassOrInterfaceDecl) {
		for (m in c.members) {
			switch m {
				case TMField(field): processClassField(field);
				case TMStaticInit(i): i.expr = processExpr(i.expr);
				case TMUseNamespace(_):
				case TMCondCompBegin(_):
				case TMCondCompEnd(_):
			}
		}
	}

	function processClassField(field:TClassField) {
		switch (field.kind) {
			case TFVar(v): processVarFields(v.vars);
			case TFFun(field): processFunction(field.fun);
			case TFGetter(field): processFunction(field.fun);
			case TFSetter(field): processFunction(field.fun);
		}
	}

	function processFunction(fun:TFunction) {
		fun.sig = processSignature(fun.sig);
		if (fun.expr != null) fun.expr = processExpr(fun.expr);
	}

	function processSignature(sig:TFunctionSignature) {
		for (arg in sig.args) {
			switch arg.kind {
				case TArgNormal(_, init):
					if (init != null) {
						init.expr = processExpr(init.expr);
					}
				case TArgRest(_):
			}
		}
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
