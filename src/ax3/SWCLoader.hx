package ax3;

import haxe.DynamicAccess;
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
	final haxeTypes:DynamicAccess<HaxeTypeAnnotation>;
	final structureSetups:Array<()->Void> = [];
	final haxeTypeResolver:HaxeTypeResolver;

	function new(tree:TypedTree, haxeTypes:DynamicAccess<HaxeTypeAnnotation>) {
		this.tree = tree;
		this.haxeTypes = haxeTypes;
		haxeTypeResolver = new HaxeTypeResolver(
			function(path) {
				var parts = path.split(".");
				var name = parts.pop();
				return tree.getDecl(parts.join("."), name);
			},
			(msg,_) -> throw msg
		);
	}

	public static function load(tree:TypedTree, haxeTypes:DynamicAccess<HaxeTypeAnnotation>, files:Array<String>) {
		// loading is done in two steps:
		// 1. create modules and empty/untyped declarations
		// 2. resolve type references
		//   - setup heritage: link classes/interfaces to their parents)
		//   - setup signatures: add fields with proper types linking to declarations
		var loader = new SWCLoader(tree, haxeTypes);
		for (file in files) {
			var swf = getLibrary(file);
			loader.processLibrary(file, swf);
		}
		for (f in loader.structureSetups) f();
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

	static function addModule(swcPath:String, tree:TypedTree, pack:String, name:String, decl:TDeclKind):TModule {
		var tPack = tree.getOrCreatePackage(pack);
		if (tPack.getModule(name) != null) {
			// trace('Duplicate module: ' + pack + "::" + name);
			return null;
		}
		var mod:TModule = {
			isExtern: true,
			path: swcPath,
			parentPack: tPack,
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
		}
		tPack.addModule(mod);
		return mod;
	}

	function getHaxeType(pack:String, clsName:String, field:String, ?accessor:String):Null<HaxeTypeAnnotation> {
		var key = [pack, clsName, field].join(".");
		if (accessor != null) key += "$" + accessor;
		return haxeTypes[key];
	}

	function processLibrary(swcPath:String, swf:SWF) {
		var abcs = getAbcs(swf);
		for (abc in abcs) {
			for (cls in abc.classes) {
				var n = getPublicName(abc, cls.name);
				if (n == null || shouldSkipClass(n.ns, n.name)) continue;

				var packName = n.ns;
				var className = n.name;

				var members:Array<TClassMember> = [];

				inline function addVar(name:String, type:TType, isStatic:Bool, isConst:Bool) {
					members.push(TMField({
						metadata: [],
						namespace: null,
						modifiers: if (isStatic) [FMStatic(null)] else [],
						kind: TFVar({
							kind: if (isConst) VConst(null) else VVar(null),
							isInline: false,
							syntax: null,
							name: name,
							type: type,
							init: null,
							semicolon: null
						})
					}));
				}

				inline function addMethod(name:String, f:TFunctionSignature, isStatic:Bool) {
					members.push(TMField({
						metadata: [],
						namespace: null,
						modifiers: if (isStatic) [FMStatic(null)] else [],
						kind: TFFun({
							syntax: null,
							name: name,
							fun: {sig: f, expr: null},
							type: TypedTreeTools.getFunctionTypeFromSignature(f),
							isInline: false,
							semicolon: null
						})
					}));
				}

				inline function addGetter(name:String, f:TFunctionSignature, isStatic:Bool) {
					members.push(TMField({
						metadata: [],
						namespace: null,
						modifiers: if (isStatic) [FMStatic(null)] else [],
						kind: TFGetter({
							syntax: null,
							name: name,
							propertyType: f.ret.type,
							haxeProperty: null,
							fun: {sig: f, expr: null},
							isInline: false,
							semicolon: null
						}),
					}));
				}

				inline function addSetter(name:String, f:TFunctionSignature, isStatic:Bool) {
					members.push(TMField({
						metadata: [],
						namespace: null,
						modifiers: if (isStatic) [FMStatic(null)] else [],
						kind: TFSetter({
							syntax: null,
							name: name,
							propertyType: f.args[0].type,
							haxeProperty: null,
							fun: {sig: f, expr: null},
							isInline: false,
							semicolon: null
						})
					}));
				}

				var clsKind;
				if (cls.isInterface) {
					var ifaceInfo = {extend: null};
					clsKind = TInterface(ifaceInfo);

					if (cls.interfaces.length > 0) {
						structureSetups.push(function() {
							var interfaces = [];
							for (iface in cls.interfaces) {
								var n = getPublicName(abc, iface, null, (ns, name) -> try {tree.getDecl(ns, name); true;} catch (e:Any) false);
								if (n != null) {
									var ifaceDecl = tree.getInterface(n.ns, n.name);
									interfaces.push({iface: {syntax: null, decl: ifaceDecl}, comma: null});
								}
							}
							ifaceInfo.extend = {keyword: null, interfaces: interfaces}
						});
					}

				} else {
					var classInfo:TClassDeclInfo = {extend: null, implement: null,};
					clsKind = TClass(classInfo);

					if (cls.superclass != null) {
						switch getPublicName(abc, cls.superclass) {
							case null | {ns: "", name: "Object" | "Array" | "Function"} | {ns: "mx.core", name: "UIComponent"} | {ns: "asunit.framework", name: "TestCase"}: // TODO: this is ugly
							case n:
								structureSetups.push(function() {
									var classDecl = switch tree.getDecl(n.ns, n.name).kind {
										case TDClassOrInterface(c) if (c.kind.match(TClass(_))): c;
										case _: throw '${n.ns}::${n.name} is not a class';
									}
									classInfo.extend = {syntax: null, superClass: classDecl};
								});
						}
					}

					structureSetups.push(function() {
						var ctor = buildFunDecl(abc, cls.constructor, getHaxeType(packName, className, "new"));
						addMethod(n.name, ctor, false);
					});

					if (cls.interfaces.length > 0) {
						classInfo.implement = {
							keyword: null,
							interfaces: []
						};
						structureSetups.push(function() {
							for (iface in cls.interfaces) {
								#if debug var failedMulti = []; #end
								var iface = getPublicName(abc, iface, null, (ns, name) -> try {tree.getDecl(ns, name); true;} catch (e:Any) {#if debug failedMulti.push({ns: ns, name: name}); #end false;});
								if (iface != null) {
									classInfo.implement.interfaces.push({
										iface: {syntax: null, decl: tree.getInterface(iface.ns, iface.name)},
										comma: null
									});
								} else {
									#if debug
									trace('could not load one of implemented interfaces for $packName::$className:');
									for (n in failedMulti) {
										trace('  - ${n.ns}::${n.name}');
									}
									#end
								}
							}
						});
					}
				}

				var dynList = [{p: 'flash.net', c: 'URLVariables'}, {p: 'flash.display', c: 'ShaderData'}];

				var tDecl:TClassOrInterfaceDecl = {
					kind: clsKind,
					syntax: null,
					metadata: [],
					modifiers: Lambda.exists(dynList, function(d) return d.p == packName && d.c == className) ? [DMDynamic(null)] : [],
					parentModule: null,
					name: n.name,
					members: members
				};
				tDecl.parentModule = addModule(swcPath, tree, n.ns, n.name, TDClassOrInterface(tDecl));

				function processField(f:format.abc.Data.Field, isStatic:Bool) {
					var n = getPublicName(abc, f.name, n.ns + ":" + n.name);
					if (n == null) return;
					// TODO: sort out namespaces
					// if (n.ns != "") throw "namespaced field name? " + n.ns;

					structureSetups.push(function() {
						switch (f.kind) {
							case FVar(type, _, isConst):
								var typeOverride = haxeTypeResolver.resolveTypeHint(getHaxeType(packName, className, n.name), 0);
								var type = if (typeOverride != null) typeOverride else if (type != null) buildTypeStructure(abc, type) else TTAny;
								addVar(n.name, type, isStatic, isConst);

							case FMethod(type, KNormal, _, _):
								addMethod(n.name, buildFunDecl(abc, type, getHaxeType(packName, className, n.name)), isStatic);

							case FMethod(type, KGetter, _, _):
								addGetter(n.name, buildFunDecl(abc, type, getHaxeType(packName, className, n.name, "get")), isStatic);

							case FMethod(type, KSetter, _, _):
								addSetter(n.name, buildFunDecl(abc, type, getHaxeType(packName, className, n.name, "set")), isStatic);

							case FClass(_) | FFunction(_): throw "should not happen";
						}
					});
				}

				for (f in cls.fields) {
					processField(f, false);
				}

				for (f in cls.staticFields) {
					processField(f, true);
				}
			}

			for (init in abc.inits) {
				for (f in init.fields) {
					var n = getPublicName(abc, f.name);
					if (n == null) continue;

					switch (f.kind) {
						case FVar(type, value, const):
							var varDecl:TModuleVarDecl = {
								metadata: [],
								modifiers: [],
								kind: if (const) VConst(null) else VVar(null),
								isInline: false,
								syntax: null,
								name: n.name,
								type: TTAny,
								init: null,
								parentModule: null,
								semicolon: null
							};
							if (type != null) {
								structureSetups.push(function() {
									var typeOverride = haxeTypeResolver.resolveTypeHint(getHaxeType(n.ns, n.name, n.name), 0);
									varDecl.type = if (typeOverride != null) typeOverride else buildTypeStructure(abc, type);
								});
							}
							varDecl.parentModule = addModule(swcPath, tree, n.ns, n.name, TDVar(varDecl));

						case FMethod(type, KNormal, _, _):
							var fun:TFunction = {sig: null, expr: null};
							structureSetups.push(() -> fun.sig = buildFunDecl(abc, type, getHaxeType(n.ns, n.name, n.name)));
							var funDecl:TFunctionDecl = {
								metadata: [],
								modifiers: [],
								syntax: null,
								name: n.name,
								parentModule: null,
								fun: fun
							};
							funDecl.parentModule = addModule(swcPath, tree, n.ns, n.name, TDFunction(funDecl));

						case FMethod(_, _, _, _):
							throw "assert";

						case FClass(_):
							// TODO: assert that class is there already (should be filled in by iterating abc.classes)
							continue;

						case FFunction(f):
							throw "assert"; // toplevel funcs are FMethods
					}
				}
			}

		}
	}

	function buildFunDecl(abc:ABCData, methType:Index<MethodType>, haxeType:Null<HaxeTypeAnnotation>):TFunctionSignature {
		var typeOverrides = haxeTypeResolver.resolveSignature(haxeType, 0);

		var methType = getMethodType(abc, methType);
		var args:Array<TFunctionArg> = [];
		for (i in 0...methType.args.length) {
			var arg = methType.args[i];
			var typeOverride = if (typeOverrides == null) null else typeOverrides.args['p${i + 1}'];
			var type = if (typeOverride != null) typeOverride else if (arg != null) buildTypeStructure(abc, arg) else TTAny;
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
				kind: TArgRest(null, TRestSwc, null),
			});
		}
		var typeOverride = if (typeOverrides == null) null else typeOverrides.ret;
		var ret = if (typeOverride != null) typeOverride else if (methType.ret != null) buildTypeStructure(abc, methType.ret) else TTAny;

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
							case ["", "Namespace"]: TTAny;
							case ["flash.utils", "Dictionary"]: tUntypedDictionary;
							case ["__AS3__.vec", "Vector"]: TTVector(TTAny); // hope that's correct
							case ["mx.core" | "mx.managers", _]: TTAny; // TODO: hacky hack
							case ["org.as3commons.reflect", _]: TTAny; // TODO hacky hack for elvenar \o/
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

	// TODO: cleanup NMulti handling
	static function getPublicName(abc:ABCData, name:IName, ?ifaceNS:String, ?multiChecker:(ns:String, name:String)->Bool):{ns:String, name:String} {
		var name = abc.get(abc.names, name);
		switch (name) {
			case NName(name, ns):
				var ns = abc.get(abc.namespaces, ns);
				switch (ns) {
					case NPublic(ns) | NProtected(ns) | NStaticProtected(ns) | NInternal(ns):
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
				var name = abc.get(abc.strings, name);
				var nss = abc.get(abc.nssets, nss);
				for (ns in nss) {
					var nsk = abc.get(abc.namespaces, ns);
					switch (nsk) {
						case NPublic(ns) | NPrivate(ns) | NInternal(ns):
							var ns = abc.get(abc.strings, ns);
							if (multiChecker == null || multiChecker(ns, name)) {
								return {ns: ns, name: name};
							}
						case _: throw "assert " + nsk.getName();
					}
				}
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
