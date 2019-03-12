package ax3;

import format.abc.Data.IName;
import format.swf.Data.SWF;
import format.abc.Data.MethodType;
import format.abc.Data.Index;
import format.abc.Data.ABCData;
import ax3.Structure;

class SWCLoader {
	public static function load(structure:Structure, file:String) {
		// trace('Loading $file');
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
					// trace('Duplicate module: ' + n.ns + "::" + n.name);
					continue;
				}

				var mod = pack.createModule(n.name);

				var decl = new SClassDecl(n.name);

				if (cls.isInterface) {
					for (iface in cls.interfaces) {
						var n = getPublicName(abc, iface);
						if (n != null) {
							decl.extensions.push(if (n.ns == "") n.name else n.ns + "." + n.name);
						}
					}
				} else {
					if (cls.superclass != null) {
						var n = getPublicName(abc, cls.superclass);
						if (n != null) {
							decl.extensions.push(if (n.ns == "") n.name else n.ns + "." + n.name);
						}
					}
				}

				function processField(f:format.abc.Data.Field, collection:FieldCollection) {
					var n = getPublicName(abc, f.name, n.ns + ":" + n.name);
					if (n == null) return;
					// TODO: sort out namespaces
					// if (n.ns != "") throw "namespaced field name? " + n.ns;

					inline function buildPublicType(type) {
						return buildTypeStructure(abc, type);
					}

					switch (f.kind) {
						case FVar(type, _, _):
							// trace("  " + n);
							collection.add({name: n.name, kind: SFVar({type: if (type != null) buildPublicType(type) else STAny})});

						case FMethod(type, KNormal, _, _):
							var methType = getMethodType(abc, type);
							var args = [];
							for (i in 0...methType.args.length) {
								var arg = methType.args[i];
								var type = if (arg != null) buildPublicType(arg) else STAny;
								args.push({kind: SArgNormal("arg", false), type: type});
							}
							if (methType.extra.variableArgs) {
								args.push({kind: SArgRest("arg"), type: STArray});
							}
							var ret = if (methType.ret != null) buildPublicType(methType.ret) else STAny;
							collection.add({name: n.name, kind: SFFun({args: args, ret: ret})});

						case FMethod(type, KGetter, _, _):
							var methType = getMethodType(abc, type);
							var type = if (methType.ret != null) buildPublicType(methType.ret) else STAny;
							if (collection.get(n.name) == null) {
								collection.add({name: n.name, kind: SFVar({type: type})});
							}

						case FMethod(type, KSetter, _, _):
							var methType = getMethodType(abc, type);
							if (methType.args.length != 1) throw "assert";
							var type = if (methType.args[0] != null) buildPublicType(methType.args[0]) else STAny;
							if (collection.get(n.name) == null) {
								collection.add({name: n.name, kind: SFVar({type: type})});
							}

						case FClass(_) | FFunction(_): throw "should not happen";
					}
				}

				for (f in cls.fields) {
					processField(f, decl.fields);
				}

				for (f in cls.staticFields) {
					processField(f, decl.statics);
				}

				mod.mainDecl = {name: n.name, kind: SClass(decl)};
			}

			for (init in abc.inits) {
				for (f in init.fields) {
					var n = getPublicName(abc, f.name);
					if (n == null) continue;

					var pack = structure.getPackage(n.ns);

					var decl = switch (f.kind) {
						case FVar(type, value, const):
							SVar({type: if (type != null) buildTypeStructure(abc, type) else STAny});
						case FMethod(type, KNormal, _, _):
							var methType = getMethodType(abc, type);
							var args = [];
							for (i in 0...methType.args.length) {
								var arg = methType.args[i];
								var type = if (arg != null) buildTypeStructure(abc, arg) else STAny;
								args.push({kind: SArgNormal("arg", false), type: type});
							}
							if (methType.extra.variableArgs) {
								args.push({kind: SArgRest("arg"), type: STArray});
							}
							var ret = if (methType.ret != null) buildTypeStructure(abc, methType.ret) else STAny;
							SFun({args: args, ret: ret});

						case FMethod(_, _, _, _):
							throw "assert";
						case FClass(_):
							// TODO: assert that class is there already (should be filled in by iterating abc.classes)
							null;
						case FFunction(f):
							throw "assert"; // toplevel funcs are FMethods
					}
					if (decl == null) continue;

					// TODO: code duplication with classes
					if (pack.getModule(n.name) != null) {
						// trace('Duplicate module: ' + n.ns + "::" + n.name);
						continue;
					}

					var mod = pack.createModule(n.name);
					mod.mainDecl = {name: n.name, kind: decl};
				}
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
									case "Number": STNumber;
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
						// trace("Loading private type as *", ns, name);
						return STAny;
					case NInternal(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						// trace("Loading internal type as *", ns, name);
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

	static function getPublicName(abc:ABCData, name:IName, ?ifaceNS:String):{ns:String, name:String} {
		var name = abc.get(abc.names, name);
		switch (name) {
			case NName(name, ns):
				var ns = abc.get(abc.namespaces, ns);
				switch (ns) {
					case NPublic(ns) | NProtected(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						return {ns: ns, name: name};
					case NNamespace(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						if (ns == "http://adobe.com/AS3/2006/builtin") {
							return {ns: "", name: name};
						} else if (ns == ifaceNS) {
							return {ns: "", name: name};
						} else {
							// trace("Ignoring namespace: " +  ns + " for " + name);
							return {ns: "", name: name};
						}
					case NPrivate(_):
						// privates are not accessible in any way, so silently skip them
						return null;
					case _:
						// trace("Skipping non-public: " +  ns.getName() + " " + abc.get(abc.strings, name));
						return null;
				}
			case NMulti(name, nss):
				// trace("OMG", abc.get(abc.strings, name));
				var nss = abc.get(abc.nssets, nss);
				for (ns in nss) {
					var nsk = abc.get(abc.namespaces, ns);
					switch (nsk) {
						case NPublic(ns) | NPrivate(ns) | NInternal(ns):
							var ns = abc.get(abc.strings, ns);
							var name = abc.get(abc.strings, name);
							return {ns: ns, name: name}
						case _: throw "assert " + nsk.getName();
					}
				}
				// TODO: ffs
				return null;
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
