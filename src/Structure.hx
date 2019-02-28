class Structure {
	public final packages:Map<String, SPackage>;

	public function new() {
		packages = [];
	}

	public function getPackage(path:String):SPackage {
		return switch packages[path] {
			case null: packages[path] = new SPackage(path);
			case pack: pack;
		};
	}

	public function dump() {
		return [for (p in packages) p.dump()].join("\n\n\n");
	}
}

class SPackage {
	public final modules:Array<SModule>;
	final moduleMap:Map<String, SModule>;

	final name:String;

	public function new(name) {
		this.name = name;
		modules = [];
		moduleMap = new Map();
	}

	public function getModule(name:String):Null<SModule> {
		return moduleMap[name];
	}

	public function createModule(name:String):SModule {
		if (moduleMap.exists(name)) throw 'Module `$name` in package `${this.name}` already exists';
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
			case STVector(t): "Vector.<" + dumpType(t) + ">";
			case STPath(path): path;
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
	STVector(t:SType);
	STPath(path:String);
}
