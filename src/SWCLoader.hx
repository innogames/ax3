import format.abc.Data.IName;
import format.swf.Data.SWF;
import format.abc.Data.MethodType;
import format.abc.Data.Index;
import format.abc.Data.ABCData;
import Structure;

class SWCLoader {
	public static function load(structure:Structure, file:String) {
		trace('Loading $file');
		processLibrary(getLibrary(file), structure);
	}

	static function shouldSkipClass(ns:String, name:String):Bool {
		return switch [ns, name] {
			case
				  ["", "Object"]
				| ["", "Class"]
				| ["", "Function"]
				| ["", "Namespace"]
				| ["", "QName"]
				| ["", "Boolean"]
				| ["", "Number"]
				| ["", "int"]
				| ["", "uint"]
				| ["", "String"]
				| ["", "Array"]
				| ["", "RegExp"]
				| ["", "XML"]
				| ["", "XMLList"]
				| ["__AS3__.vec", "Vector"]
				: true;
			case _: false;
		}
	}

	static function processLibrary(swf:SWF, structure:Structure) {
		var abcs = getAbcs(swf);
		for (abc in abcs) {
			for (cls in abc.classes) {
				var n = getPublicName(abc, cls.name);
				if (n == null || shouldSkipClass(n.ns, n.name)) continue;

				var pack = structure.getPackage(n.ns);

				if (pack.getModule(n.name) != null) {
					trace('Duplicate module: ' + n.ns + "::" + n.name);
					continue;
				}

				var mod = pack.createModule(n.name);

				var decl = new SClassDecl(n.name);
				// trace(n);

				for (f in cls.fields) {
					var n = getPublicName(abc, f.name);
					if (n == null) continue;
					if (n.ns != "") throw "namespaced field name?";

					inline function buildPublicType(type) {
						return buildTypeStructure(abc, type);
					}

					switch (f.kind) {
						case FVar(type, _, _):
							// trace("  " + n);
							decl.addField({name: n.name, kind: SFVar({type: if (type != null) buildPublicType(type) else STAny})});

						case FMethod(type, KNormal, _, _):
							var methType = getMethodType(abc, type);
							var args = [];
							for (i in 0...methType.args.length) {
								var arg = methType.args[i];
								var type = if (arg != null) buildPublicType(arg) else STAny;
								args.push(SArgNormal("arg", false, type));
							}
							var ret = if (methType.ret != null) buildPublicType(methType.ret) else STAny;
							decl.addField({name: n.name, kind: SFFun({args: args, ret: ret})});

						case FMethod(type, KGetter, _, _):
							var methType = getMethodType(abc, type);
							var type = if (methType.ret != null) buildPublicType(methType.ret) else STAny;
							if (decl.getField(n.name) == null) {
								decl.addField({name: n.name, kind: SFVar({type: type})});
							}

						case FMethod(type, KSetter, _, _):
							var methType = getMethodType(abc, type);
							if (methType.args.length != 1) throw "assert";
							var type = if (methType.args[0] != null) buildPublicType(methType.args[0]) else STAny;
							if (decl.getField(n.name) == null) {
								decl.addField({name: n.name, kind: SFVar({type: type})});
							}

						case FClass(_) | FFunction(_): throw "should not happen";
					}
				}

				mod.mainDecl = {name: n.name, kind: SClass(decl)};
			}
		}
	}

	static function getMethodType(abc:ABCData, i:Index<MethodType> ) : MethodType {
		return switch i { case Idx(n): abc.methodTypes[n]; };
	}

	static function buildTypeStructure(abc:ABCData, name:IName):SType {
		switch abc.get(abc.names, name) {
			case NName(name, ns):
				switch (abc.get(abc.namespaces, ns)) {
					case NPublic(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						return switch ns {
							case "":
								switch name {
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
									case _: STPath(name);
								}
							case _:
								STPath(ns + "." + name);
						}
					case NPrivate(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						trace("Loading private type as *", ns, name);
						return STAny;
					case NInternal(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						trace("Loading internal type as *", ns, name);
						return STAny;
					case other:
						throw "assert" + other.getName();
				}

			case NParams(n, [type]):
				var n = getPublicName(abc, n);
				switch [n.ns, n.name] {
					case ["__AS3__.vec", "Vector"]:
						return STVector(buildTypeStructure(abc, type));
					case _:
						throw "assert: " + n;
				}

			case _:
				throw "assert";
		}
	}

	static function getPublicName(abc:ABCData, name:IName):{ns:String, name:String} {
		var name = abc.get(abc.names, name);
		switch (name) {
			case NName(name, ns):
				var ns = abc.get(abc.namespaces, ns);
				switch (ns) {
					case NPublic(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						return {ns: ns, name: name};
					case NNamespace(ns) if (abc.get(abc.strings, ns) == "http://adobe.com/AS3/2006/builtin"):
						return {ns: "", name: abc.get(abc.strings, name)};
					case _:
						// trace("Skipping non-public: " +  ns.getName() + " " + abc.get(abc.strings, name));
						return null;
				}
			case _:
				throw "assert " + name.getName();
		}
	}

	static function getAbcs(swf:SWF):Array<ABCData> {
		var result = [];
		for (tag in swf.tags) {
			switch (tag) {
				case TActionScript3(data, context):
					result.push(new format.abc.Reader(new haxe.io.BytesInput(data)).read());
				case _:
			}
		}
		return result;
	}

	static function getLibrary(file:String):SWF {
		var entries = haxe.zip.Reader.readZip(sys.io.File.read(file));
		for (entry in entries) {
			if (entry.fileName == "library.swf") {
				var data = haxe.zip.Reader.unzip(entry);
				return new format.swf.Reader(new haxe.io.BytesInput(data)).read();
			}
		}
		throw "no library.swf found";
	}
}
