package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;

class Structure {
	public final packages:Map<String, SPackage>;

	function new() {
		packages = [];
	}

	public function getConstructor(cls:SClassDecl):Null<SFunDecl> {
		function loop(c:SClassDecl) {
			var ctor = c.fields.get(c.name);
			if (ctor != null) {
				return ctor;
			} else {
				for (ext in c.extensions) {
					ctor = loop(getClass(ext));
					if (ctor != null) {
						return ctor;
					}
				}
			}
			return null;
		}
		var ctor = loop(cls);
		return switch ctor {
			case null: null;
			case {kind: SFFun(f)}: f;
			case {kind: SFVar(_)}: throw "assert";
		};
	}

	public function getClass(fqn:String):SClassDecl {
		var pack, name;
		switch fqn.lastIndexOf(".") {
			case -1: pack = ""; name = fqn;
			case index:
				pack = fqn.substring(0, index);
				name = fqn.substring(index + 1);
		}
		return switch getDecl(pack, name).kind {
			case SClass(c): c;
			case _: throw "assert";
		}
	}

	public function getPrivateClass(mod:String, cls:String):SClassDecl {
		var pack, name;
		switch mod.lastIndexOf(".") {
			case -1: pack = ""; name = mod;
			case index:
				pack = mod.substring(0, index);
				name = mod.substring(index + 1);
		}

		return switch packages[pack] {
			case null: throw "no such package " + pack;
			case p:
				var mod = p.getModule(name);
				if (mod == null) throw 'no such module $pack::$name';
				return mod.getPrivateClass(cls);
		}
	}

	public function getDecl(pack:String, name:String):SDecl {
		switch packages[pack] {
			case null: throw 'declaration not found $pack::$name';
			case p:
				var mod = p.getModule(name);
				if (mod == null) throw 'declaration not found $pack::$name';
				return mod.mainDecl;
		}
	}

	public function getPackage(path:String):SPackage {
		return switch packages[path] {
			case null: throw 'No such package $path';
			case pack: pack;
		};
	}

	public function getOrCreatePackage(path:String):SPackage {
		return switch packages[path] {
			case null: packages[path] = new SPackage(path, this);
			case pack: pack;
		};
	}

	public function checkValidFullPath(packName:String, declName:String) {
		switch packages[packName] {
			case null:
				return false;
			case pack:
				var mod = pack.getModule(declName);
				return (mod != null);
		}
	}

	public static function build(files:Array<File>, libs:Array<String>):Structure {
		var structure = new Structure();
		var t = stamp();
		for (lib in libs) {
			SWCLoader.load(structure, lib);
		}
		Timers.swcs += (stamp() - t);
		t = stamp();
		for (file in files) {
			StructureBuilder.buildModule(structure, file);
		}
		Timers.structure += (stamp() - t);
		t = stamp();
		structure.resolve();
		Timers.resolve += (stamp() - t);
		return structure;
	}

	public function resolve() {
		for (pack in packages) {
			for (mod in pack.modules) {
				function resolveType(t:SType) {
					return switch (t) {
						case STVoid | STAny | STBoolean | STNumber | STInt | STUint | STString | STArray | STFunction | STClass | STObject | STXML | STXMLList | STRegExp | STUnresolved(_): t;
						case STPrivate(_): throw "assert"; // this is only produces as a result of resolution
						case STVector(t): STVector(resolveType(t));
						case STPath(path): mod.resolveTypePath(path);
					};
				}

				function resolveFun(f:SFunDecl) {
					for (a in f.args) {
						a.type = resolveType(a.type);
					}
					f.ret = resolveType(f.ret);
				}

				function resolveVar(v:SVarDecl) {
					v.type = resolveType(v.type);
				}

				function resolveField(f:SClassField) {
					switch (f.kind) {
						case SFVar(v): resolveVar(v);
						case SFFun(f): resolveFun(f);
					}
				}

				function resolveDecl(d:SDecl) {
					switch (d.kind) {
						case SNamespace:
							// nothing to resolve
						case SVar(v):
							resolveVar(v);
						case SFun(f):
							resolveFun(f);
						case SClass(f):
							f.extensions = [
								for (path in f.extensions) {
									// TODO: this is dirty
									if (path != "Object" && path != "mx.core.UIComponent") {
										switch (mod.resolveTypePath(path)) {
											case STPath(path): path;
											case STUnresolved(path): throw "Unknown extension: " + path;
											case _: throw "assert";
										}
									}
								}
							];

							for (f in @:privateAccess f.fields) {
								resolveField(f);
							}
							for (f in @:privateAccess f.statics) {
								resolveField(f);
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

}

class SPackage {
	public final modules:Array<SModule>;
	final moduleMap:Map<String, SModule>;

	public final name:String;
	final stucture:Structure;

	public function new(name, structure) {
		this.name = name;
		this.stucture = structure;
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
				// trace('Duplicate module `$name` in package `${this.name}`');
				modules.remove(existing);
		}
		var module = new SModule(name, this, stucture);
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
	public final pack:SPackage;

	final name:String;
	final structure:Structure;

	public function new(name, pack:SPackage, structure:Structure) {
		this.name = name;
		this.pack = pack;
		this.structure = structure;
		imports = [];
		privateDecls = [];
	}

	public function getDecl(name:String):Null<SDecl> {
		if (mainDecl.name == name) return mainDecl;
		for (decl in privateDecls) if (decl.name == name) return decl;
		return null;
	}

	public function getMainClass(name:String):Null<SClassDecl> {
		if (mainDecl.name == name) {
			return switch mainDecl.kind {
				case SClass(c): c;
				case _: null;
			}
		}
		return null;
	}

	public function getPrivateClass(name:String):Null<SClassDecl> {
		for (p in privateDecls) {
			if (p.name == name) {
				return switch p.kind {
					case SClass(c): c;
					case _: null;
				}
			}
		}
		return null;
	}

	public function resolveTypePath(path:String) {
		var dotIndex = path.lastIndexOf(".");
		if (dotIndex != -1) {
			// already a full-path, check that it's present
			var packName = path.substring(0, dotIndex);
			var declName = path.substring(dotIndex + 1);
			if (!structure.checkValidFullPath(packName, declName)) {
				return STUnresolved(path);
			}
			return STPath(path);
		}

		inline function fq(pack:String, name:String) {
			return if (pack == "") name else pack + "." + name;
		}

		// TODO: these only should work for SClass declarations
		if (mainDecl.name == path) {
			return STPath(fq(pack.name, path));
		}
		for (decl in privateDecls) {
			if (decl.name == path) {
				return STPrivate(fq(pack.name, name), path);
			}
		}

		for (i in imports) {
			switch (i) {
				case SISingle(pack, name):
					if (name == path) {
						if (!structure.checkValidFullPath(pack, name)) {
							return STUnresolved(fq(pack,name));
						}
						return STPath(fq(pack, name));
					}
				case SIAll(pack):
					switch structure.packages[pack] {
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

		if (structure.checkValidFullPath("", path)) {
			// toplevel type
			return STPath(path);
		}

		return STUnresolved(path);
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
			case SNamespace:
				return indent + "NS " + d.name;
			case SClass(f):
				var r = [indent + "CLS " + d.name];
				if (f.extensions.length > 0) {
					r.push(indent + " - EXT: " + f.extensions.join(", "));
				}
				for (field in @:privateAccess f.fields) {
					r.push(dumpClassField(field));
				}
				for (field in @:privateAccess f.statics) {
					r.push(dumpClassField(field, "STATIC "));
				}
				return r.join("\n");
		}
	}

	static function dumpVar(name:String, v:SVarDecl):String {
		return "VAR " + name + ":" + dumpType(v.type);
	}

	static function dumpFun(name:String, f:SFunDecl):String {
		var args = [for (a in f.args) switch (a.kind) {
			case SArgNormal(name, opt): (if (opt) "?" else "") + name + ":" + dumpType(a.type);
			case SArgRest(name): "..." + name;
		}];
		return "FUN " + name + "(" + args.join(", ") + "):" + dumpType(f.ret);
	}

	static function dumpClassField(f:SClassField, prefix = ""):String {
		var prefix = indent + indent + indent + indent + prefix;
		return switch (f.kind) {
			case SFVar(v): prefix + dumpVar(f.name, v);
			case SFFun(fun): prefix + dumpFun(f.name, fun);
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
			case STPrivate(path, name): 'PRIVATE<$path::$name>';
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
	SNamespace;
}

typedef SVarDecl = {
	var swc:Bool;
	var type:SType;
}

typedef SFunDecl = {
	var swc:Bool;
	var args:Array<{kind:SFunArgKind, type:SType}>;
	var ret:SType;
}

enum SFunArgKind {
	SArgNormal(name:String, opt:Bool);
	SArgRest(name:String);
}

@:forward(iterator)
abstract FieldCollection(Map<String,SClassField>) {
	public function new() this = new Map();

	public function get(name) return this.get(name);

	public function add(field:SClassField) {
		if (this.exists(field.name)) throw 'Field `${field.name}` is already declared';
		this.set(field.name, field);
	}
}

class SClassDecl {
	public var extensions:Array<String>;
	public final name:String;

	public final fields = new FieldCollection();
	public final statics = new FieldCollection();

	public function new(name) {
		this.name = name;
		this.extensions = [];
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
	STPrivate(mod:String, name:String);
	STUnresolved(path:String);
}
