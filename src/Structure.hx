import ParseTree;
import Utils.dotPathToArray;
import Utils.foldSeparated;

class Structure {
	public final packages:Map<String, SPackage>;

	function new() {
		packages = [];
	}

	public function getPackage(path:String):SPackage {
		return switch packages[path] {
			case null: packages[path] = new SPackage(path);
			case pack: pack;
		};
	}

	public static function build(files:Array<File>, libs:Array<String>):Structure {
		var structure = new Structure();
		for (lib in libs) {
			SWCLoader.load(structure, lib);
		}
		for (file in files) {
			structure.buildModule(file);
		}
		structure.resolve();
		return structure;
	}

	public function buildModule(file:File) {
		var pack = getPackageDecl(file);

		var mainDecl = getPackageMainDecl(pack);

		var privateDecls = getPrivateDecls(file);

		var imports = getImports(file);

		// TODO: just skipping conditional-compiled ones for now
		if (mainDecl == null) return;

		var packName = getPackagePath(pack).join(".");
		var sPack = getPackage(packName);
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

	public function resolve() {
		for (pack in packages) {
			for (mod in pack.modules) {

				function checkValidPath(packName:String, declName:String) {
					switch packages[packName] {
						case null:
							return false;
							throw "No such package " + packName;
						case pack:
							var mod = pack.getModule(declName);
							if (mod == null) {
								return false;
								throw "No such type " + declName;
							}
					}
					return true;
				}

				function resolvePath(path:String) {
					var dotIndex = path.lastIndexOf(".");
					if (dotIndex != -1) {
						// already a full-path, check that it's present
						var packName = path.substring(0, dotIndex);
						var declName = path.substring(dotIndex + 1);
						if (!checkValidPath(packName, declName)) {
							return STUnresolved(path);
						}
						return STPath(path);
					}

					inline function fq(pack:String, name:String) {
						return if (pack == "") name else pack + "." + name;
					}

					if (mod.mainDecl.name == path) {
						return STPath(fq(pack.name, path));
					}

					var imports = mod.imports.copy();
					imports.reverse();

					for (i in imports) {
						switch (i) {
							case SISingle(pack, name):
								if (name == path) {
									if (!checkValidPath(pack, name)) {
										return STUnresolved(fq(pack,name));
									}
									return STPath(fq(pack, name));
								}
							case SIAll(pack):
								switch packages[pack] {
									case null:
										return STUnresolved(path);
									case p:
										var m = p.getModule(path);
										if (m != null) {
											return STPath(fq(pack, path));
										}
								}
						}
					}

					var modInPack = pack.getModule(path);
					if (modInPack != null) {
						return STPath(fq(pack.name, path));
					}

					if (checkValidPath("", path)) {
						// toplevel type
						return STPath(path);
					}

					return STUnresolved(path);
				}

				function resolveType(t:SType) {
					return switch (t) {
						case STVoid | STAny | STBoolean | STNumber | STInt | STUint | STString | STArray | STFunction | STClass | STObject | STXML | STXMLList | STRegExp | STUnresolved(_): t;
						case STVector(t): STVector(resolveType(t));
						case STPath(path): resolvePath(path);
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

	public function dump() {
		return [for (p in packages) p.dump()].join("\n\n\n");
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
				switch dotPathToArray(path).join(".").toString() {
					case "void": STVoid;
					case "Boolean": STBoolean;
					case "Number": STUint;
					case "int": STInt;
					case "uint": STUint;
					case "String": STString;
					case "Array": STArray;
					case "Class": STClass;
					case "Object": STObject;
					case "Function": STFunction;
					case "XML": STXML;
					case "XMLList": STXMLList;
					case "RegExp": STRegExp;
					case other: STPath(other);
				}
			case TVector(v): STVector(buildTypeStructure(v.t.type));
		}
	}
}

class SPackage {
	public final modules:Array<SModule>;
	final moduleMap:Map<String, SModule>;

	public final name:String;

	public function new(name) {
		this.name = name;
		modules = [];
		moduleMap = new Map();
	}

	public function getModule(name:String):Null<SModule> {
		return moduleMap[name];
	}

	public function createModule(name:String):SModule {
		switch moduleMap[name] {
			case null:
			case existing:
				trace('Duplicate module `$name` in package `${this.name}`');
				modules.remove(existing);
		}
		var module = new SModule(name);
		modules.push(module);
		moduleMap[name] = module;
		return module;
	}

	public function dump() {
		return (if (name == "") "<root>" else name) + "\n" + [for (m in modules) m.dump()].join("\n\n");
	}
}

enum SImport {
	SISingle(pack:String, name:String);
	SIAll(pack:String);
}

class SModule {
	public var mainDecl:SDecl;
	public var privateDecls(default,null):Array<SDecl>;
	public final imports:Array<SImport>;

	final name:String;

	public function new(name) {
		this.name = name;
		imports = [];
		privateDecls = [];
	}

	static final indent = "  ";

	public function dump() {
		var r = [indent + name];
		if (mainDecl != null) {
			r.push(indent + indent + "MAIN:");
			r.push(dumpDecl(mainDecl));
		}
		if (privateDecls.length > 0) {
			r.push(indent + indent + "PRIVATE:");
			for (d in privateDecls) {
				r.push(dumpDecl(d));
			}
		}
		return r.join("\n");
	}

	static function dumpDecl(d:SDecl):String {
		var indent = indent + indent + indent;
		switch (d.kind) {
			case SVar(v):
				return indent + dumpVar(d.name, v);
			case SFun(f):
				return indent + dumpFun(d.name, f);
			case SClass(f):
				var r = [indent + "CLS " + d.name];
				for (field in f.fields) {
					r.push(dumpClassField(field));
				}
				return r.join("\n");
		}
	}

	static function dumpVar(name:String, v:SVarDecl):String {
		return "VAR " + name + ":" + dumpType(v.type);
	}

	static function dumpFun(name:String, f:SFunDecl):String {
		var args = [for (a in f.args) switch (a) {
			case SArgNormal(name, opt, type): (if (opt) "?" else "") + name + ":" + dumpType(type);
			case SArgRest(name): "..." + name;
		}];
		return "FUN " + name + "(" + args.join(", ") + "):" + dumpType(f.ret);
	}

	static function dumpClassField(f:SClassField):String {
		var indent = indent + indent + indent + indent;
		return switch (f.kind) {
			case SFVar(v): indent + dumpVar(f.name, v);
			case SFFun(fun): indent + dumpFun(f.name, fun);
		}
	}

	static function dumpType(t:SType):String {
		return switch (t) {
			case STVoid: "void";
			case STAny: "*";
			case STBoolean: "Boolean";
			case STNumber: "Number";
			case STInt: "int";
			case STUint: "uint";
			case STString: "String";
			case STArray: "Array";
			case STFunction: "Function";
			case STClass: "Class";
			case STObject: "Object";
			case STXML: "XML";
			case STXMLList: "XMLList";
			case STRegExp: "RegExp";
			case STVector(t): "Vector.<" + dumpType(t) + ">";
			case STPath(path): path;
			case STUnresolved(path): 'UNRESOLVED<$path>';
		}
	}
}

typedef SDecl = {
	var name:String;
	var kind:SDeclKind;
}

enum SDeclKind {
	SVar(v:SVarDecl);
	SFun(f:SFunDecl);
	SClass(f:SClassDecl);
}

typedef SVarDecl = {
	var type:SType;
}

typedef SFunDecl = {
	var args:Array<SFunArg>;
	var ret:SType;
}

enum SFunArg {
	SArgNormal(name:String, opt:Bool, type:SType);
	SArgRest(name:String);
}

class SClassDecl {
	public final fields:Array<SClassField>;
	final fieldMap:Map<String, SClassField>;

	final name:String;

	public function new(name) {
		this.name = name;
		fields = [];
		fieldMap = new Map();
	}

	public function addField(f:SClassField) {
		if (fieldMap.exists(f.name)) throw 'Field `${f.name} is already declared in class `$name`';
		fields.push(f);
		fieldMap[f.name] = f;
	}

	public function getField(name:String):SClassField {
		return fieldMap[name];
	}
}

typedef SClassField = {
	var name:String;
	var kind:SClassFieldKind;
}

enum SClassFieldKind {
	SFVar(v:SVarDecl);
	SFFun(f:SFunDecl);
}

enum SType {
	STVoid;
	STAny;
	STBoolean;
	STNumber;
	STInt;
	STUint;
	STString;
	STArray;
	STFunction;
	STClass;
	STObject;
	STXML;
	STXMLList;
	STRegExp;
	STVector(t:SType);
	STPath(path:String);
	STUnresolved(path:String);
}
