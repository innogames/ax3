import ParseTree;
import Structure;

class Typer2 {
	public function new() {}

	public function process(files:Array<File>) {
		buildStructure(files);
		resolveStructure();
		sys.io.File.saveContent("structure.txt", structure.dump());
	}

	var structure:Structure;

	function buildStructure(files:Array<File>) {
		structure = new Structure();
		for (file in files) {
			buildModule(file);
		}
	}

	function resolveStructure() {
		for (pack in structure.packages) {
			for (mod in pack.modules) {

				function resolvePath(path:String) {
					if (path.indexOf(".") != -1) {
						// already a full-path
						return path;
					}

					var imports = mod.imports.copy();
					imports.reverse();

					inline function fq(pack:String, name:String) {
						return if (pack == "") name else pack + "." + name;
					}

					for (i in imports) {
						switch (i) {
							case SISingle(pack, name):
								if (name == path) {
									return fq(pack, name);
								}
							case SIAll(pack):
								switch structure.packages[pack] {
									case null: throw "No such package: " + pack;
									case p:
										var m = p.getModule(path);
										if (m != null) {
											return fq(pack, path);
										}
								}
						}
					}

					throw "Unresolved type: " + path;
				}

				function resolveType(t:SType) {
					return switch (t) {
						case STVoid | STAny | STBoolean | STNumber | STInt | STUint | STString | STArray | STFunction: t;
						case STVector(t): STVector(resolveType(t));
						case STPath(path): STPath(resolvePath(path));
					};
				}

				function resolveFun(f:SFunDecl) {
					f.args = f.args.map(a -> switch (a) {
						case SArgNormal(name, opt, type): SArgNormal(name, opt, resolveType(type));
						case SArgRest(_): a;
					});
					f.ret = resolveType(f.ret);
				}

				function resolveVar(v:SVarDecl) {
					v.type = resolveType(v.type);
				}

				function resolveDecl(d:SDecl) {
					switch (d.kind) {
						case SVar(v):
							resolveVar(v);
						case SFun(f):
							resolveFun(f);
						case SClass(f):
							for (f in f.fields) {
								switch (f.kind) {
									case SFVar(v): resolveVar(v);
									case SFFun(f): resolveFun(f);

								}
							}
					}
				}

				resolveDecl(mod.mainDecl);
				for (d in mod.privateDecls) {
					resolveDecl(d);
				}
			}
		}
	}

	function buildModule(file:File) {
		var pack = getPackageDecl(file);

		var mainDecl = getPackageMainDecl(pack);

		var privateDecls = getPrivateDecls(file);

		var imports = getImports(file);

		// TODO: just skipping conditional-compiled ones for now
		if (mainDecl == null) return;

		var packName = getPackagePath(pack).join(".");
		var sPack = structure.getPackage(packName);
		var sModule = sPack.createModule(file.name);

		sModule.mainDecl = {
			var dl = buildDeclStructure(mainDecl);
			if (dl.length > 1) throw "more than one main declarations?"; // shouldn't happen really
			dl[0];
		};

		for (d in privateDecls) {
			for (s in buildDeclStructure(d))
				sModule.privateDecls.push(s);
		}

		for (i in imports)
			sModule.imports.push(buildImport(i));
	}

	function buildImport(i:ImportDecl):SImport {
		var path = dotPathToArray(i.path);
		return if (i.wildcard != null) SIAll(path.join(".")) else {var name = path.pop(); SISingle(path.join("."), name);}
	}

	function buildDeclStructure(d:Declaration):Array<SDecl> {
		switch (d) {
			case DClass(c):
				return [buildClassStructure(c)];
			case DInterface(i):
				return [buildInterfaceStructure(i)];
			case DFunction(f):
				return [{name: f.name.text, kind: SFun(buildFunctionStructure(f.fun.signature))}];
			case DVar(v):
				return foldSeparated(v.vars, [], (v, acc) -> acc.push({name: v.name.text, kind: SVar(buildVarStructure(v))}));
			case DPackage(_) | DImport(_) | DNamespace(_) | DUseNamespace(_, _) | DCondComp(_, _, _, _):
				throw "Unexpected module declaration";
		}
	}

	function buildClassStructure(v:ClassDecl):SDecl {
		var cls = new SClassDecl(v.name.text);
		for (m in v.members) {
			switch (m) {
				case MField(f):
					switch (f.kind) {
						case FVar(_, vars, _):
							foldSeparated(vars, null, function(v, _) {
								var s = buildVarStructure(v);
								cls.addField({name: v.name.text, kind: SFVar(s)});
							});
						case FFun(_, name, fun):
							var fun = buildFunctionStructure(fun.signature);
							cls.addField({name: name.text, kind: SFFun(fun)});
						case FProp(_, _, name, fun):
							var type = buildTypeStructure(fun.signature.ret.type);
							if (cls.getField(name.text) != null) {
								// TODO: check if it was really a property getter/setter
								cls.addField({name: name.text, kind: SFVar({type: type})});
							}
					}

				case MCondComp(v, openBrace, members, closeBrace):
					// TODO:

				case MStaticInit(_) | MUseNamespace(_, _):
			}
		}
		return {
			name: v.name.text,
			kind: SClass(cls)
		};
	}

	function buildInterfaceStructure(v:InterfaceDecl):SDecl {
		var cls = new SClassDecl(v.name.text);
		for (m in v.members) {
			switch (m) {
				case MIField(f):
					switch (f.kind) {
						case IFFun(_, name, fun):
							var fun = buildFunctionStructure(fun);
							cls.addField({name: name.text, kind: SFFun(fun)});
						case IFProp(_, kind, name, fun):
							var type = buildTypeStructure(fun.ret.type);
							if (cls.getField(name.text) != null) {
								// TODO: check if it was really a property getter/setter
								cls.addField({name: name.text, kind: SFVar({type: type})});
							}
					}
				case MICondComp(v, openBrace, members, closeBrace):
					// TODO
			}
		}
		return {
			name: v.name.text,
			kind: SClass(cls)
		};
	}

	function buildFunctionStructure(sig:FunctionSignature):SFunDecl {
		function buildArg(arg:FunctionArg) {
			return switch (arg) {
				case ArgNormal(a): SArgNormal(a.name.text, a.init != null, if (a.type == null) STAny else buildTypeStructure(a.type.type));
				case ArgRest(_, name): SArgRest(name.text);
			}
		}

		return {
			args: if (sig.args == null) [] else foldSeparated(sig.args, [], (arg,acc) -> acc.push(buildArg(arg))),
			ret: if (sig.ret == null) STAny else buildTypeStructure(sig.ret.type)
		};
	}

	function buildVarStructure(v:VarDecl):SVarDecl {
		var type = if (v.type == null) STAny else buildTypeStructure(v.type.type);
		return {type: type};
	}

	function buildTypeStructure(t:SyntaxType):SType {
		return switch (t) {
			case TAny(star): STAny;
			case TPath(path):
				switch dotPathToArray(path).toString() {
					case "void": STVoid;
					case "Boolean": STBoolean;
					case "Number": STUint;
					case "int": STInt;
					case "uint": STUint;
					case "String": STString;
					case "Array": STArray;
					case "Function": STFunction;
					case other: STPath(other);
				}
			case TVector(v): STVector(buildTypeStructure(v.t.type));
		}
	}

	function foldSeparated<T,S>(d:Separated<T>, acc:S, f:(T,S)->Void):S {
		f(d.first, acc);
		for (p in d.rest) {
			f(p.element, acc);
		}
		return acc;
	}

	function dotPathToArray(d:DotPath):Array<String> {
		return foldSeparated(d, [], (part, acc) -> acc.push(part.text));
	}

	function getPackagePath(p:PackageDecl):Array<String> {
		return if (p.name != null) dotPathToArray(p.name) else [];
	}

	function getImports(file:File) {
		var result = [];
		function loop(decls:Array<Declaration>) {
			for (d in decls) {
				switch (d) {
					case DPackage(p): loop(p.declarations);
					case DImport(i): result.push(i);
					case _: // TODO: handle cond.compilation
				}
			}
		}
		loop(file.declarations);
		return result;
	}

	function getPackageDecl(file:File):PackageDecl {
		var pack = null;
		for (decl in file.declarations) {
			switch (decl) {
				case DPackage(p):
					if (pack != null) throw 'Duplicate package decl in ${file.name}';
					pack = p;
				case _:
			}
		}
		if (pack == null) throw "No package declaration in " + file.name;
		return pack;
	}

	function getPrivateDecls(file:File):Array<Declaration> {
		var decls = [];
		for (d in file.declarations) {
			switch (d) {
				case DPackage(p): // in-package is the main one

				case DClass(_) | DInterface(_) | DFunction(_) | DVar(_):
					decls.push(d);

				// skip these for now
				case DImport(i):
				case DNamespace(ns):
				case DUseNamespace(n, semicolon):
				case DCondComp(v, openBrace, decls, closeBrace):
			}
		}
		return decls;
	}

	function getPackageMainDecl(p:PackageDecl):Declaration {
		var decl = null;
		for (d in p.declarations) {
			switch (d) {
				case DPackage(p):
					throw "Package inside package is not allowed";

				case DClass(_) | DInterface(_) | DFunction(_) | DVar(_):
					if (decl != null) throw "More than one declaration inside package";
					decl = d;

				// skip these for now
				case DImport(_):
				case DNamespace(_):
				case DUseNamespace(_):
				case DCondComp(_):
			}
		}
		// TODO: just skipping conditional-compiled ones for now
		// if (decl == null) throw "No declaration inside package";
		return decl;
	}
}
