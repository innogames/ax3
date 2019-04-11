package ax3;

import format.abc.Data.IName;
import format.swf.Data.SWF;
import format.abc.Data.MethodType;
import format.abc.Data.Index;
import format.abc.Data.ABCData;
import ax3.Token.nullToken;
import ax3.TypedTree;
import ax3.TypedTreeTools.tUntypedArray;
import ax3.TypedTreeTools.tUntypedObject;
import ax3.TypedTreeTools.tUntypedDictionary;

class SWCLoader {
	final tree:TypedTree;

	function new(tree:TypedTree) {
		this.tree = tree;
	}

	public static function load(tree:TypedTree, files:Array<String>) {
		// loading is done in two steps:
		// 1. create modules and empty/untyped declarations
		// 2. resolve type references
		//   - setup heritage: link classes/interfaces to their parents)
		//   - setup signatures: add fields with proper types linking to declarations
		var loader = new SWCLoader(tree);
		for (file in files) {
			var swf = getLibrary(file);
			loader.processLibrary(file, swf);
		}
		tree.flush();
	}

	static function shouldSkipClass(ns:String, name:String):Bool {
		return switch [ns, name] {
			case
				  ["", "Object"]
				| ["", "Class"]
				| ["", "Function"]
				| ["", "Namespace"]
				// | ["", "QName"]
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
				// | ["flash.utils", "Dictionary"]
				: true;
			case _: false;
		}
	}

	static function addModule(swcPath:String, tree:TypedTree, pack:String, name:String, decl:TDeclKind) {
		var tPack = tree.getOrCreatePackage(pack);
		if (tPack.getModule(name) != null) {
			// trace('Duplicate module: ' + pack + "::" + name);
			return;
		}
		tPack.addModule({
			path: swcPath,
			pack: {
				syntax: null,
				imports: [],
				namespaceUses: [],
				name: pack,
				decl: {name: name, kind: decl}
			},
			name: name,
			privateDecls: [],
			eof: nullToken
		});
	}

	function processLibrary(swcPath:String, swf:SWF) {
		var abcs = getAbcs(swf);
		for (abc in abcs) {
			for (cls in abc.classes) {
				var n = getPublicName(abc, cls.name);
				if (n == null || shouldSkipClass(n.ns, n.name)) continue;

				var tDecl, addVar, addMethod, addGetter, addSetter;
				if (cls.isInterface) {
					var members:Array<TInterfaceMember> = [];

					addVar = function(name:String, type:TType) throw 'Var $name in interface ${n.name}';
					addMethod = function(name:String, f:TFunctionSignature) {
						members.push(TIMField({
							metadata: [],
							semicolon: null,
							kind: TIFFun({
								syntax: null,
								name: name,
								sig: f
							})
						}));
					}
					addGetter = function(name:String, f:TFunctionSignature) {
						members.push(TIMField({
							metadata: [],
							semicolon: null,
							kind: TIFGetter({
								syntax: null,
								name: name,
								sig: f
							})
						}));
					}
					addSetter = function(name:String, f:TFunctionSignature) {
						members.push(TIMField({
							metadata: [],
							semicolon: null,
							kind: TIFSetter({
								syntax: null,
								name: name,
								sig: f
							})
						}));
					}

					var iface:TInterfaceDecl = {
						syntax: null,
						metadata: [],
						modifiers: [],
						name: n.name,
						extend: null,
						members: members
					};
					tDecl = TDInterface(iface);

					var extensions = [];
					for (iface in cls.interfaces) {
						var ifaceN = getPublicName(abc, iface);
						if (ifaceN != null) {
							if (ifaceN.name == "DRMErrorListener") {
								// TODO: something is bugged here, or I don't understand how to read SWC properly
								ifaceN.ns = "com.adobe.tvsdk.mediacore";
							}
							extensions.push(ifaceN);
						}
					}

					if (extensions.length > 0) {
						tree.delay(function() {
							var interfaces = [];
							for (n in extensions) {
								var ifaceDecl = tree.getInterface(n.ns, n.name);
								interfaces.push({iface: {syntax: null, decl: ifaceDecl}, comma: null});
							}
							iface.extend = {
								syntax: null,
								interfaces: interfaces
							}
						});
					}

				} else {
					var members:Array<TClassMember> = [];

					addVar = function(name:String, type:TType) {
						members.push(TMField({
							metadata: [],
							namespace: null,
							modifiers: [],
							kind: TFVar({
								kind: VVar(null),
								isInline: false,
								vars: [{
									syntax: null,
									name: name,
									type: type,
									init: null,
									comma: null
								}],
								semicolon: null
							})
						}));
					}
					addMethod = function(name:String, f:TFunctionSignature) {
						members.push(TMField({
							metadata: [],
							namespace: null,
							modifiers: [],
							kind: TFFun({
								syntax: null,
								name: name,
								fun: {sig: f, expr: null}
							})
						}));
					}
					addGetter = function(name:String, f:TFunctionSignature) {
						members.push(TMField({
							metadata: [],
							namespace: null,
							modifiers: [],
							kind: TFGetter({
								syntax: null,
								name: name,
								fun: {sig: f, expr: null}
							})
						}));
					}
					addSetter = function(name:String, f:TFunctionSignature) {
						members.push(TMField({
							metadata: [],
							namespace: null,
							modifiers: [],
							kind: TFSetter({
								syntax: null,
								name: name,
								fun: {sig: f, expr: null}
							})
						}));
					}

					var tCls:TClassDecl = {
						syntax: null,
						properties: null,
						metadata: [],
						modifiers: [],
						name: n.name,
						structure: null,
						extend: null,
						implement: null,
						members: members
					};
					tDecl = TDClass(tCls);

					if (cls.superclass != null) {
						switch getPublicName(abc, cls.superclass) {
							case null | {ns: "", name: "Object"} | {ns: "mx.core", name: "UIComponent"}: // ignore mx.core.UIComponent
							case n:
								tree.delay(function() {
									var classDecl = switch tree.getDecl(n.ns, n.name).kind {
										case TDClass(c): c;
										case _: throw '${n.ns}::${n.name} is not a class';
									}
									tCls.extend = {syntax: null, superClass: classDecl};
								});
						}
					}

					tree.delay(function() {
						var ctor = buildFunDecl(abc, cls.constructor);
						addMethod(n.name, ctor);
					});
				}

				function processField(f:format.abc.Data.Field) {
					var n = getPublicName(abc, f.name, n.ns + ":" + n.name);
					if (n == null) return;
					// TODO: sort out namespaces
					// if (n.ns != "") throw "namespaced field name? " + n.ns;

					inline function buildPublicType(type) {
						return buildTypeStructure(abc, type);
					}

					tree.delay(function() {
						switch (f.kind) {
							case FVar(type, _, _):
								addVar(n.name, if (type != null) buildPublicType(type) else TTAny);

							case FMethod(type, KNormal, _, _):
								addMethod(n.name, buildFunDecl(abc, type));

							case FMethod(type, KGetter, _, _):
								addGetter(n.name, buildFunDecl(abc, type));

							case FMethod(type, KSetter, _, _):
								addSetter(n.name, buildFunDecl(abc, type));

							case FClass(_) | FFunction(_): throw "should not happen";
						}
					});
				}

				for (f in cls.fields) {
					processField(f);
				}

				for (f in cls.staticFields) {
					processField(f);
				}

				addModule(swcPath, tree, n.ns, n.name, tDecl);
			}

			for (init in abc.inits) {
				for (f in init.fields) {
					var n = getPublicName(abc, f.name);
					if (n == null) continue;

					var decl = switch (f.kind) {
						case FVar(type, value, const):
							var v:TVarFieldDecl = {
								syntax: null,
								name: n.name,
								type: TTAny,
								init: null,
								comma: null
							};

							if (type != null) {
								tree.delay(() -> v.type = buildTypeStructure(abc, type));
							}

							TDVar({
								metadata: [],
								modifiers: [],
								kind: if (const) VConst(null) else VVar(null),
								isInline: false,
								vars: [v],
								semicolon: null
							});

						case FMethod(type, KNormal, _, _):
							var fun:TFunction = {sig: null, expr: null};
							tree.delay(() -> fun.sig = buildFunDecl(abc, type));
							TDFunction({
								metadata: [],
								modifiers: [],
								syntax: null,
								name: n.name,
								fun: fun
							});

						case FMethod(_, _, _, _):
							throw "assert";

						case FClass(_):
							// TODO: assert that class is there already (should be filled in by iterating abc.classes)
							continue;

						case FFunction(f):
							throw "assert"; // toplevel funcs are FMethods
					}

					addModule(swcPath, tree, n.ns, n.name, decl);
				}
			}

		}
	}

	function buildFunDecl(abc:ABCData, methType:Index<MethodType>):TFunctionSignature {
		var methType = getMethodType(abc, methType);
		var args:Array<TFunctionArg> = [];
		for (i in 0...methType.args.length) {
			var arg = methType.args[i];
			var type = if (arg != null) buildTypeStructure(abc, arg) else TTAny;
			args.push({
				syntax: null,
				comma: null,
				name: "arg" + i,
				type: type,
				v: null,
				kind: TArgNormal(null, null),
			});
		}
		if (methType.extra != null && methType.extra.variableArgs) {
			args.push({
				syntax: null,
				comma: null,
				name: "rest",
				type: tUntypedArray,
				v: null,
				kind: TArgRest(null),
			});
		}
		var ret = if (methType.ret != null) buildTypeStructure(abc, methType.ret) else TTAny;

		return {
			syntax: null,
			args: args,
			ret: {
				syntax: null,
				type: ret
			}
		};
	}

	static function getMethodType(abc:ABCData, i:Index<MethodType> ) : MethodType {
		return abc.methodTypes[i.asInt()];
	}

	inline function resolveTypePath(ns:String, n:String):TType {
		return TypedTree.declToInst(tree.getDecl(ns, n));
	}

	function buildTypeStructure(abc:ABCData, name:IName):TType {
		switch abc.get(abc.names, name) {
			case NName(name, ns):
				switch (abc.get(abc.namespaces, ns)) {
					case NPublic(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						return switch [ns, name] {
							case ["", "void"]: TTVoid;
							case ["", "Boolean"]: TTBoolean;
							case ["", "Number"]: TTNumber;
							case ["", "int"]: TTInt;
							case ["", "uint"]: TTUint;
							case ["", "String"]: TTString;
							case ["", "Array"]: tUntypedArray;
							case ["", "Object"]: tUntypedObject;
							case ["", "Class"]: TTClass;
							case ["", "Function"]: TTFunction;
							case ["", "XML"]: TTXML;
							case ["", "XMLList"]: TTXMLList;
							case ["", "RegExp"]: TTRegExp;
							case ["flash.utils", "Dictionary"]: tUntypedDictionary;
							case ["mx.core", _]: TTAny; // TODO: hacky hack
							case _: resolveTypePath(ns, name);
						}
					case NPrivate(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						// trace("Loading private type as *", ns, name);
						return TTAny;
					case NInternal(ns):
						var ns = abc.get(abc.strings, ns);
						var name = abc.get(abc.strings, name);
						// trace("Loading internal type as *", ns, name);
						return TTAny;
					case other:
						throw "assert" + other.getName();
				}

			case NParams(n, [type]):
				var n = getPublicName(abc, n);
				switch [n.ns, n.name] {
					case ["__AS3__.vec", "Vector"]:
						return TTVector(buildTypeStructure(abc, type));
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
