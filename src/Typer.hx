import haxe.ds.Map;
import sys.io.File;
import TypedTree;
import Utils.createDirectory;

class Typer {
	var files:Array<ParseTree.File>;

	var modules:Array<TModule>;
	var moduleMap:Map<String,TModule>;

	public function new() {
		files = [];
	}

	public function addFile(file:ParseTree.File) {
		files.push(file);
	}

	public function process() {
		buildStructure();
		resolveTypes();
	}

	function buildStructure() {
		modules = [];
		moduleMap = new Map();
		for (file in files) {

			var packageDecl = null;

			for (decl in file.declarations) {
				switch (decl) {
					case DPackage(p):
						if (packageDecl == null)
							packageDecl = p;
						else
							throw "duplicate package declaration!";

					case _:
						throw "TODO: " + decl.getName();
				}
			}

			if (packageDecl == null) throw "no package declaration!";

			var mainType = null;

			for (decl in packageDecl.declarations) {
				switch (decl) {
					case DClass(c):
						if (mainType == null)
							mainType = TDClass(processClassDecl(c));
						else
							throw "more than one main type!";
					case _:
						throw "TODO: " + decl.getName();
				}
			}

			if (mainType == null) throw "no main type!";

			var module:TModule = {
				syntax: file,
				mainType: mainType
			};

			var pack = getPack(packageDecl);
			var path = pack.concat([file.name]).join(".");
			moduleMap[path] = module;
			modules.push(module);
		}
	}

	function resolveTypes() {
		for (module in modules) {
		}
	}

	function processClassDecl(c:ParseTree.ClassDecl):TClass {
		var fields = new Array<TClassField>();
		var fieldMap = new Map();

		inline function addField(field:TClassField) {
			var name = field.name.text;
			if (fieldMap.exists(name))
				throw 'Field $name already exists!';
			fields.push(field);
			fieldMap[name] = field;
		}

		for (m in c.members) {
			switch (m) {
				case MCondComp(v, openBrace, members, closeBrace):
					trace("TODO: conditional compilation");
				case MUseNamespace(n, semicolon):
					trace("TODO: use namespace");
				case MStaticInit(block):
					trace("TODO: static init");
				case MField(f):
					switch (f.kind) {
						case FVar(kind, vars, semicolon):
							var tVars = [];

							var prev:TClassField;

							inline function add(name:Token) {
								tVars.push(prev = {name: name, kind: null});
							}

							add(vars.first.name);
							for (v in vars.rest) {
								prev.kind = TFVar(kind, v.sep);
								add(v.element.name);
							}

							tVars[tVars.length - 1].kind = TFVar(kind, semicolon);

							for (v in tVars) {
								addField(v);
							}

						case FFun(keyword, name, fun):
							trace("TODO: function");
						case FProp(keyword, kind, name, fun):
							trace("TODO: property");
					}
			}
		}

		return {
			syntax: c,
			fields: fields,
			fieldMap: fieldMap,
		};
	}

	public function write(outDir:String) {
		return;
		// for (m in modules) {
		// 	var pack = getPack(m.pack);
		// 	var dir = outDir + pack.join("/");
		// 	createDirectory(dir);
		// 	var outFile = dir + "/" + m.name + ".hx";
		// 	// var gen = new GenHaxe();
		// 	// gen.writeModule(m);
		// 	// File.saveContent(outFile, gen.getContent());
		// }
	}

	static function getPack(p:ParseTree.PackageDecl):Array<String> {
		var result = [];
		if (p.name != null) {
			result.push(p.name.first.text);
			for (el in p.name.rest) {
				result.push(el.element.text);
			}
		}
		return result;
	}
}
