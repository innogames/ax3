package ax3.filters;

class AbstractFilter {
	final context:Context;

	var currentPath:Null<String>;
	var tree: TypedTree;

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
		processImports(mod);
		processDecl(mod.pack.decl);

		for (decl in mod.privateDecls) {
			processDecl(decl);
		}
	}

	function processImports(mod:TModule) {
		var newImports = [];
		var condCompBegin = null;
		var prevImport = null;
		for (i in mod.pack.imports) {
			var keep = processImport(i);
			if (keep) {
				newImports.push(i);
				if (condCompBegin != null) {
					if (i.syntax.condCompBegin != null) throw "assert"; // this will be annoying to deal with
					i.syntax.condCompBegin = condCompBegin;
					condCompBegin = null;
				}
				prevImport = i;
			} else {
				var trivia = i.syntax.keyword.leadTrivia.concat(i.syntax.semicolon.trailTrivia);
				if (!TokenTools.containsOnlyWhitespaceOrNewline(trivia)) {
					// TODO: this is a very hacky way to keep trivia:
					// GenHaxe will skip TDNamespace and only print its trivia
					newImports.push({
						syntax: {
							condCompBegin: null,
							keyword: i.syntax.keyword,
							path: i.syntax.path,
							semicolon: i.syntax.semicolon,
							condCompEnd: null
						},
						kind: TIDecl({name: null, kind: TDNamespace(null)})
					});
				}

				if (i.syntax.condCompBegin != null) {
					if (condCompBegin != null) throw "assert"; // this will be annoying to deal with
					condCompBegin = i.syntax.condCompBegin;
				}
				if (i.syntax.condCompEnd != null) {
					if (prevImport != null) {
						if (prevImport.syntax.condCompEnd != null) throw "assert"; // this will be annoying to deal with
						prevImport.syntax.condCompEnd = i.syntax.condCompEnd;
					}
				}
			}
		}
		mod.pack.imports = newImports;
	}

	public function run(tree:TypedTree) {
		this.tree = tree;
		for (pack in tree.packages) {
			var mods = [for (mod in pack) mod]; // save the list because we might modify the package (e.g. rename the module)
			for (mod in mods) {
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
			case TDVar(v): processVarField(v);
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
			case TFVar(v): processVarField(v);
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

	function processVarField(v:TVarField) {
		if (v.init != null) {
			v.init.expr = processExpr(v.init.expr);
		}
	}
}
