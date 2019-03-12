package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;
import ax3.Structure;

class StructureBuilder {
	public static function buildTypeStructure(t:SyntaxType, ?resolveModule:SModule):SType {
		return switch (t) {
			case TAny(_): STAny;
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
					case other: if (resolveModule != null) resolveModule.resolveTypePath(other) else STPath(other);
				}
			case TVector(v): STVector(buildTypeStructure(v.t.type, resolveModule));
		}
	}

	public static function buildModule(structure:Structure, file:File) {
		var pack = getPackageDecl(file);

		var mainDecl = getPackageMainDecl(pack);

		var privateDecls = getPrivateDecls(file);

		var imports = getImports(file);

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


	static function buildImport(i:ImportDecl):SImport {
		var path = dotPathToArray(i.path);
		return if (i.wildcard != null) SIAll(path.join(".")) else {var name = path.pop(); SISingle(path.join("."), name);}
	}

	static function buildDeclStructure(d:Declaration):Array<SDecl> {
		switch (d) {
			case DClass(c):
				return [buildClassStructure(c)];
			case DInterface(i):
				return [buildInterfaceStructure(i)];
			case DFunction(f):
				return [{name: f.name.text, kind: SFun(buildFunctionStructure(f.fun.signature))}];
			case DVar(v):
				return foldSeparated(v.vars, [], (v, acc) -> acc.push({name: v.name.text, kind: SVar(buildVarStructure(v))}));
			case DNamespace(n):
				return [{name: n.name.text, kind: SNamespace}];
			case DPackage(_) | DImport(_) | DUseNamespace(_, _) | DCondComp(_, _, _, _):
				throw "Unexpected module declaration";
		}
	}

	static function buildClassStructure(v:ClassDecl):SDecl {
		var cls = new SClassDecl(v.name.text);
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
						var isStatic = Lambda.exists(f.modifiers, m -> m.match(FMStatic(_)));
						var fieldCollection = if (isStatic) cls.statics else cls.fields;

						switch (f.kind) {
							case FVar(_, vars, _):
								foldSeparated(vars, null, function(v, _) {
									var s = buildVarStructure(v);
									fieldCollection.add({name: v.name.text, kind: SFVar(s)});
								});
							case FFun(_, name, fun):
								var fun = buildFunctionStructure(fun.signature);
								fieldCollection.add({name: name.text, kind: SFFun(fun)});
							case FGetter(_, _, name, fun):
								var type = buildTypeStructure(fun.signature.ret.type);
								if (fieldCollection.get(name.text) == null) {
									// TODO: check if it was really a property getter/setter
									fieldCollection.add({name: name.text, kind: SFVar({type: type})});
								}
							case FSetter(_, _, name, fun):
								var type = switch (fun.signature.args.first) {
									case ArgNormal(a): buildTypeStructure(a.type.type);
									case ArgRest(_, _): throw "assert";
								};
								if (fieldCollection.get(name.text) == null) {
									// TODO: check if it was really a property getter/setter
									fieldCollection.add({name: name.text, kind: SFVar({type: type})});
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

	static function buildInterfaceStructure(v:InterfaceDecl):SDecl {
		var cls = new SClassDecl(v.name.text);
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
									cls.fields.add({name: name.text, kind: SFVar({type: type})});
								}
							case IFSetter(_, _, name, fun):
								var type = switch (fun.args.first) {
									case ArgNormal(a): buildTypeStructure(a.type.type);
									case ArgRest(_, _): throw "assert";
								};
								if (cls.fields.get(name.text) == null) {
									// TODO: check if it was really a property getter/setter
									cls.fields.add({name: name.text, kind: SFVar({type: type})});
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
					{kind: SArgNormal(a.name.text, a.init != null), type: type};
				case ArgRest(_, name):
					{kind: SArgRest(name.text), type: STArray};
			}
		}

		return {
			args: if (sig.args == null) [] else foldSeparated(sig.args, [], (arg,acc) -> acc.push(buildArg(arg))),
			ret: if (sig.ret == null) STAny else buildTypeStructure(sig.ret.type)
		};
	}

	static function buildVarStructure(v:VarDecl):SVarDecl {
		var type = if (v.type == null) STAny else buildTypeStructure(v.type.type);
		return {type: type};
	}

	static function getPackagePath(p:PackageDecl):Array<String> {
		return if (p.name != null) dotPathToArray(p.name) else [];
	}
}
