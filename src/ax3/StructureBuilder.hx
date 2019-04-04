package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;
import ax3.Structure;
import ax3.Structure.stUntypedObject;
import ax3.Structure.stUntypedArray;
import ax3.HaxeTypeAnnotation;

class StructureBuilder {
	public static function makeFQN(ns:String, n:String):String {
		return if (ns == "") n else ns + "." + n;
	}

	public static function buildTypeStructure(t:SyntaxType, ?resolveModule:SModule):SType {
		return switch (t) {
			case TAny(_): STAny;
			case TPath(path):
				Structure.changeDictionary(switch dotPathToArray(path).join(".").toString() {
					case "void": STVoid;
					case "Boolean": STBoolean;
					case "Number": STNumber;
					case "int": STInt;
					case "uint": STUint;
					case "String": STString;
					case "Array": Structure.stUntypedArray;
					case "Object": Structure.stUntypedObject;
					case "Class": STClass;
					case "Function": STFunction;
					case "XML": STXML;
					case "XMLList": STXMLList;
					case "RegExp": STRegExp;
					case other: if (resolveModule != null) resolveModule.resolveTypePath(other) else STPath(other);
				});
			case TVector(v): STVector(buildTypeStructure(v.t.type, resolveModule));
		}
	}

	public static function buildModule(structure:Structure, file:File) {
		var pack = getPackageDecl(file);

		var mainDecl = getPackageMainDecl(pack);

		var privateDecls = getPrivateDecls(file);

		var imports = getImports(file);

		var packName = getPackagePath(pack).join(".");
		var sPack = structure.getOrCreatePackage(packName);
		var sModule = sPack.createModule(file.name);

		sModule.mainDecl = {
			var dl = buildDeclStructure(mainDecl, packName);
			if (dl.length > 1) throw "more than one main declarations?"; // shouldn't happen really
			dl[0];
		};

		for (d in privateDecls) {
			for (s in buildDeclStructure(d, null))
				sModule.privateDecls.push(s);
		}

		for (i in imports)
			sModule.imports.push(buildImport(i));
	}


	static function buildImport(i:ImportDecl):SImport {
		var path = dotPathToArray(i.path);
		return if (i.wildcard != null) SIAll(path.join(".")) else {var name = path.pop(); SISingle(path.join("."), name);}
	}

	static function buildDeclStructure(d:Declaration, pack:Null<String>):Array<SDecl> {
		switch (d) {
			case DClass(c):
				return [buildClassStructure(c, pack)];
			case DInterface(i):
				return [buildInterfaceStructure(i, pack)];
			case DFunction(f):
				return [{name: f.name.text, kind: SFun(buildFunctionStructure(f.fun.signature))}];
			case DVar(v):
				var overrideType = resolveHaxeTypeHint(HaxeTypeAnnotation.extractFromModuleVarDecl(v), v.vars.first.name.pos);
				return foldSeparated(v.vars, [], (v, acc) -> acc.push({name: v.name.text, kind: SVar(buildVarStructure(v, overrideType))}));
			case DNamespace(n):
				return [{name: n.name.text, kind: SNamespace}];
			case DPackage(_) | DImport(_) | DUseNamespace(_, _) | DCondComp(_, _, _, _):
				throw "Unexpected module declaration";
		}
	}

	static function buildClassStructure(v:ClassDecl, pack:String):SDecl {
		var cls = new SClassDecl(v.name.text, if (pack == null) null else makeFQN(pack, v.name.text));
		if (v.extend != null) {
			cls.extensions.push(dotPathToString(v.extend.path));
		}
		// maybe we don't need that for struct because all public fields
		// will be there anyway
		// if (v.implement != null) {
		// 	iterSeparated(v.implement.paths, p -> cls.extensions.push(dotPathToString(p)));
		// }

		function loop(members:Array<ClassMember>) {
			for (m in members) {
				switch (m) {
					case MField(f):
						var haxeType = HaxeTypeAnnotation.extractFromClassField(f);

						var isStatic = Lambda.exists(f.modifiers, m -> m.match(FMStatic(_)));
						var fieldCollection = if (isStatic) cls.statics else cls.fields;

						switch (f.kind) {
							case FVar(_, vars, _):
								var overrideType = resolveHaxeTypeHint(haxeType, vars.first.name.pos);

								foldSeparated(vars, null, function(v, _) {
									var s = buildVarStructure(v, overrideType);
									fieldCollection.add({name: v.name.text, kind: SFVar(s)});
								});
							case FFun(_, name, fun):
								var fun = buildFunctionStructure(fun.signature);
								fieldCollection.add({name: name.text, kind: SFFun(fun)});
							case FGetter(_, _, name, fun):
								var type = buildTypeStructure(fun.signature.ret.type);
								if (fieldCollection.get(name.text) == null) {
									// TODO: check if it was really a property getter/setter
									fieldCollection.add({name: name.text, kind: SFVar({swc: true, type: type})});
								}
							case FSetter(_, _, name, fun):
								var type = switch (fun.signature.args.first) {
									case ArgNormal(a): buildTypeStructure(a.type.type);
									case ArgRest(_, _): throw "assert";
								};
								if (fieldCollection.get(name.text) == null) {
									// TODO: check if it was really a property getter/setter
									fieldCollection.add({name: name.text, kind: SFVar({swc: true, type: type})});
								}
						}

					case MCondComp(v, openBrace, members, closeBrace):
						loop(members);

					case MStaticInit(_) | MUseNamespace(_, _):
				}
			}
		}

		loop(v.members);

		return {
			name: v.name.text,
			kind: SClass(cls)
		};
	}

	static function buildInterfaceStructure(v:InterfaceDecl, pack:Null<String>):SDecl {
		var cls = new SClassDecl(v.name.text, if (pack == null) null else makeFQN(pack, v.name.text));
		if (v.extend != null) {
			iterSeparated(v.extend.paths, p -> cls.extensions.push(dotPathToString(p)));
		}

		function loop(members:Array<InterfaceMember>) {
			for (m in members) {
				switch (m) {
					case MIField(f):
						switch (f.kind) {
							case IFFun(_, name, fun):
								var fun = buildFunctionStructure(fun);
								cls.fields.add({name: name.text, kind: SFFun(fun)});
							case IFGetter(_, _, name, fun):
								var type = buildTypeStructure(fun.ret.type);
								if (cls.fields.get(name.text) == null) {
									// TODO: check if it was really a property getter/setter
									cls.fields.add({name: name.text, kind: SFVar({swc: true, type: type})});
								}
							case IFSetter(_, _, name, fun):
								var type = switch (fun.args.first) {
									case ArgNormal(a): buildTypeStructure(a.type.type);
									case ArgRest(_, _): throw "assert";
								};
								if (cls.fields.get(name.text) == null) {
									// TODO: check if it was really a property getter/setter
									cls.fields.add({name: name.text, kind: SFVar({swc: true, type: type})});
								}
						}
					case MICondComp(v, openBrace, members, closeBrace):
						loop(members);
				}
			}
		}

		loop(v.members);

		return {
			name: v.name.text,
			kind: SClass(cls)
		};
	}

	static function buildFunctionStructure(sig:FunctionSignature):SFunDecl {
		function buildArg(arg:FunctionArg) {
			return switch (arg) {
				case ArgNormal(a):
					var type = if (a.type == null) STAny else buildTypeStructure(a.type.type);
					{name: a.name.text, kind: SArgNormal(a.init != null), type: type};
				case ArgRest(_, name):
					{name: name.text, kind: SArgRest, type: Structure.stUntypedArray};
			}
		}

		return {
			args: if (sig.args == null) [] else foldSeparated(sig.args, [], (arg,acc) -> acc.push(buildArg(arg))),
			ret: if (sig.ret == null) STAny else buildTypeStructure(sig.ret.type),
			swc: false,
		};
	}

	static function buildVarStructure(v:VarDecl, overrideType:Null<SType>):SVarDecl {
		var type = if (overrideType != null) overrideType else if (v.type == null) STAny else buildTypeStructure(v.type.type);
		return {swc: true, type: type};
	}

	static function getPackagePath(p:PackageDecl):Array<String> {
		return if (p.name != null) dotPathToArray(p.name) else [];
	}

	static function resolveHaxeTypeHint(a:Null<HaxeTypeAnnotation>, p:Int):Null<SType> {
		return if (a == null) null else resolveHaxeType(a.parseTypeHint(), p);
	}

	static function resolveHaxeType(t:HaxeType, pos:Int):SType {
		return switch t {
			case HTPath("Array", [elemT]): STArray(resolveHaxeType(elemT, pos));
			case HTPath("Int", []): STInt;
			case HTPath("UInt", []): STUint;
			case HTPath("Float", []): STNumber;
			case HTPath("Bool", []): STBoolean;
			case HTPath("String", []): STString;
			case HTPath("Dynamic", []): STAny;
			case HTPath("Void", []): STVoid;
			case HTPath("FastXML", []): STXML;
			case HTPath("haxe.DynamicAccess", [elemT]): STObject(resolveHaxeType(elemT, pos));
			case HTPath("flash.utils.Object", []): stUntypedObject;
			case HTPath("Vector" | "flash.Vector", [t]): STVector(resolveHaxeType(t, pos));
			case HTPath("GenericDictionary", [k, v]): STDictionary(resolveHaxeType(k, pos), resolveHaxeType(v, pos));
			case HTPath("Class", [HTPath("Dynamic", [])]): STClass;
			case HTPath("Class", [HTPath(name, [])]): STClass; // TODO?
			case HTPath("Null", [t]): resolveHaxeType(t, pos); // TODO: keep nullability?
			case HTPath(path, []): STPath(path);
			case HTPath(path, _): trace("TODO: " + path); STAny;
			case HTFun(args, ret): STFun([for (a in args) resolveHaxeType(a, pos)], resolveHaxeType(ret, pos));
		};
	}
}
