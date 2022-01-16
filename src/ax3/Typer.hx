package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;
import ax3.TypedTree;
import ax3.TypedTreeTools.tUntypedArray;
import ax3.TypedTreeTools.tUntypedObject;
import ax3.TypedTreeTools.tUntypedDictionary;
import ax3.TypedTreeTools.getFunctionTypeFromSignature;
import ax3.TypedTreeTools.mk;
import ax3.HaxeTypeAnnotation;

class Typer {
	public static function process(context:Context, tree:TypedTree, files:Array<File>) {
		var typer = new Typer(context, tree);
		for (file in files) {
			typer.processFile(file);
		}
		for (f in typer.importSetups) f();
		for (f in typer.structureSetups) f();
		for (f in typer.exprTypings) f();
	}

	final context:Context;
	final tree:TypedTree;

	final importSetups:Array<()->Void> = [];
	final structureSetups:Array<()->Void> = [];
	final exprTypings:Array<()->Void> = [];

	function new(context, tree) {
		this.context = context;
		this.tree = tree;
	}

	function processFile(file:File) {
		var pack = getPackageDecl(file);
		var packName = if (pack.name == null) "" else dotPathToString(pack.name);
		var tPack = tree.getOrCreatePackage(packName);

		var tModule:TModule = {
			isExtern: false,
			path: file.path,
			parentPack: tPack,
			name: file.name,
			pack: {
				syntax: pack,
				name: packName,
				imports: [],
				namespaceUses: getNamespaceUses(pack),
				decl: null,
			},
			privateDecls: [],
			eof: file.eof
		}

		importSetups.push(() -> tModule.pack.imports = typeImports(file, tModule));

		tModule.pack.decl = typeDecl(getPackageMainDecl(pack, tModule), tModule);
		for (decl in getPrivateDecls(file)) {
			tModule.privateDecls.push(typeDecl(decl, tModule));
		}

		tPack.replaceModule(tModule);
	}

	function getPackageMainDecl(pack:PackageDecl, mod:TModule):Declaration {
		return try ParseTree.getPackageMainDecl(pack) catch (e:Any) throwErr(mod, Std.string(e), pack.keyword.pos);
	}

	function typeDecl(d:Declaration, mod:TModule):TDecl {
		var moduleTyperContext = makeTyperContext(mod, null);
		return switch (d) {
			case DPackage(_) | DImport(_) | DUseNamespace(_): throw "assert";
			case DClass(c):
				{name: c.name.text, kind: TDClassOrInterface(typeClass(c, mod))};
			case DInterface(i):
				{name: i.name.text, kind: TDClassOrInterface(typeInterface(i, mod))};
			case DFunction(f):
				{name: f.name.text, kind: TDFunction(typeModuleFunction(f, mod, moduleTyperContext))};
			case DVar(v):
				var v = typeModuleVar(v, mod, moduleTyperContext);
				{name: v.name, kind: TDVar(v)};
			case DNamespace(ns):
				{name: null, kind: TDNamespace(ns)};
			case DCondComp(v, openBrace, decls, closeBrace): throw "TODO";
			case _: null;
		}
	}

	function typeModuleVar(decl:ModuleVarDecl, mod:TModule, typerContext:ExprTyper.TyperContext):TModuleVarDecl {
		if (decl.vars.rest.length > 0) {
			throwErr(mod, "Multiple module var declaration is not supported", decl.vars.rest[0].element.name.pos);
		}

		var v = decl.vars.first;

		var overrideType = HaxeTypeAnnotation.extractFromModuleVarDecl(decl);
		var moduleVar:TModuleVarDecl = {
			parentModule: mod,
			metadata: typeMetadata(decl.metadata),
			modifiers: decl.modifiers,
			kind: decl.kind,
			syntax:{
				name: v.name,
				type: v.type
			},
			name: v.name.text,
			type: null,
			init: null,
			semicolon: decl.semicolon,
			isInline: false,
		};

		structureSetups.push(function() {
			var overrideType = typerContext.haxeTypes.resolveTypeHint(overrideType, v.name.pos); // TODO: no need to resolve this more than once
			moduleVar.type = if (overrideType != null) overrideType else if (v.type == null) TTAny else resolveType(mod, v.type.type);
		});

		if (v.init != null) {
			exprTypings.push(() -> moduleVar.init = typeVarInit(mod, v.init, moduleVar.type, typerContext));
		}

		return moduleVar;
	}

	function makeTyperContext(mod:TModule, cls:Null<TClassOrInterfaceDecl>):ExprTyper.TyperContext {
		return {
			getCurrentClass: () -> cls,
			reportError: err.bind(mod),
			throwError: throwErr.bind(mod),
			resolveDotPath: resolveDotPath.bind(mod),
			resolveType: resolveType.bind(mod),
			haxeTypes: new HaxeTypeResolver(path -> resolveDotPath(mod, path.split(".")), throwErr.bind(mod))
		};
	}

	function typeMetadata(metadata:Array<Metadata>):Array<TMetadata> {
		return metadata.map(MetaFlash);
	}

	function typeModuleFunction(v:FunctionDecl, mod:TModule, typerContext:ExprTyper.TyperContext):TFunctionDecl {
		var typeOverrides = HaxeTypeAnnotation.extractFromModuleFunDecl(v);
		var d:TFunctionDecl = {
			metadata: typeMetadata(v.metadata),
			modifiers: v.modifiers,
			syntax: {keyword: v.keyword, name: v.name},
			name: v.name.text,
			parentModule: mod,
			fun: {
				sig: null,
				expr: null
			}
		};
		structureSetups.push(() -> d.fun.sig = typeFunctionSignature(v.fun.signature, typeOverrides, typerContext));
		exprTypings.push(() -> d.fun.expr = new ExprTyper(context, tree, typerContext).typeFunctionExpr(d.fun.sig, v.fun.block));
		return d;
	}

	function typeClassImplement(mod:TModule, i:{keyword:Token, paths:Separated<DotPath>}):TClassImplement {
		return {
			keyword: i.keyword,
			interfaces: separatedToArray(i.paths, function(path, comma) {
				var ifaceDecl = switch resolveDotPath(mod, dotPathToArray(path)).kind {
					case TDClassOrInterface(i) if (i.kind.match(TInterface(_))): i;
					case _: throw "Not an interface";
				}
				return {iface: {syntax: path, decl: ifaceDecl}, comma: comma}
			})
		};
	}

	function typeClass(c:ClassDecl, mod:TModule):TClassOrInterfaceDecl {
		var tMembers = [];
		var info:TClassDeclInfo = {extend: null, implement: null};

		if (c.extend != null) {
			structureSetups.push(function() {
				var classDecl = switch resolveDotPath(mod, dotPathToArray(c.extend.path)).kind {
					case TDClassOrInterface(i) if (i.kind.match(TClass(_))): i;
					case _: throw "Not a ccass";
				}
				info.extend = {syntax: c.extend, superClass: classDecl};
			});
		}

		if (c.implement != null) {
			structureSetups.push(function() {
				structureSetups.push(() -> info.implement = typeClassImplement(mod, c.implement));
			});
		}

		var tCls:TClassOrInterfaceDecl = {
			kind: TClass(info),
			syntax: c,
			parentModule: mod,
			name: c.name.text,
			metadata: typeMetadata(c.metadata),
			modifiers: c.modifiers,
			members: tMembers
		}

		structureSetups.push(function() {
			var typerContext = makeTyperContext(mod, tCls);
			function loop(members:Array<ClassMember>) {
				for (m in members) {
					switch (m) {
						case MCondComp(v, openBrace, members, closeBrace):
							tMembers.push(TMCondCompBegin({v: ExprTyper.typeCondCompVar(v), openBrace: openBrace}));
							loop(members);
							tMembers.push(TMCondCompEnd({closeBrace: closeBrace}));
						case MUseNamespace(n, semicolon):
							tMembers.push(TMUseNamespace(n, semicolon));
						case MField(f):
							tMembers.push(TMField(typeClassField(mod, f, typerContext)));
						case MStaticInit(block):
							exprTypings.push(function() {
								var expr = mk(TEBlock(new ExprTyper(context, tree, typerContext).typeBlock(block)), TTVoid, TTVoid);
								tMembers.push(TMStaticInit({expr: expr}));
							});
					}
				}
			}
			loop(c.members);
		});

		return tCls;
	}

	function typeClassField(mod:TModule, f:ClassField, typerContext:ExprTyper.TyperContext):TClassField {
		var haxeType = HaxeTypeAnnotation.extractFromClassField(f);

		inline function typeFunction(fun:Function):TFunction {
			var tFun:TFunction = {
				sig: typeFunctionSignature(fun.signature, haxeType, typerContext),
				expr: null,
			};
			exprTypings.push(() -> tFun.expr = new ExprTyper(context, tree, typerContext).typeFunctionExpr(tFun.sig, fun.block));
			return tFun;
		}

		var kind = switch (f.kind) {
			case FVar(kind, vars, semicolon):
				TFVar(typeVarField(mod, kind, vars, semicolon, haxeType, typerContext));
			case FFun(keyword, name, fun):
				var fun = typeFunction(fun);
				TFFun({
					syntax: {
						keyword: keyword,
						name: name,
					},
					name: name.text,
					fun: fun,
					type: getFunctionTypeFromSignature(fun.sig),
					isInline: false,
					semicolon: null
				});
			case FGetter(keyword, get, name, fun):
				var fun = typeFunction(fun);
				TFGetter({
					syntax: {
						functionKeyword: keyword,
						accessorKeyword: get,
						name: name,
					},
					name: name.text,
					propertyType: fun.sig.ret.type,
					haxeProperty: null,
					fun: fun,
					isInline: false,
					semicolon: null
				});
			case FSetter(keyword, set, name, fun):
				var fun = typeFunction(fun);
				TFSetter({
					syntax: {
						functionKeyword: keyword,
						accessorKeyword: set,
						name: name,
					},
					name: name.text,
					propertyType: fun.sig.args[0].type,
					haxeProperty: null,
					fun: fun,
					isInline: false,
					semicolon: null
				});
		}
		return {
			metadata: typeMetadata(f.metadata),
			namespace: f.namespace,
			modifiers: f.modifiers,
			kind: kind
		};
	}

	function typeVarField(mod:TModule, kind:VarDeclKind, vars:Separated<VarDecl>, semicolon:Token, haxeType:Null<HaxeTypeAnnotation>, typerContext:ExprTyper.TyperContext):TVarField {
		if (vars.rest.length > 0) {
			throwErr(mod, "Multiple var field declaration is not supported", vars.rest[0].element.name.pos);
		}

		var v = vars.first;

		var overrideType = typerContext.haxeTypes.resolveTypeHint(haxeType, v.name.pos);
		var type:TType = if (overrideType != null) overrideType else if (v.type == null) TTAny else resolveType(mod, v.type.type);

		var varField:TVarField = {
			kind: kind,
			syntax:{
				name: v.name,
				type: v.type
			},
			name: v.name.text,
			type: type,
			init: null,
			semicolon: semicolon,
			isInline: false,
		};

		if (v.init != null) {
			exprTypings.push(() -> varField.init = typeVarInit(mod, v.init, type, typerContext));
		}

		return varField;
	}

	function typeVarInit(mod:TModule, init:VarInit, expectedType:TType, typerContext:ExprTyper.TyperContext):TVarInit {
		return {equalsToken: init.equalsToken, expr: new ExprTyper(context, tree, typerContext).typeExpr(init.expr, expectedType)};
	}

	function typeInterface(i:InterfaceDecl, mod:TModule):TClassOrInterfaceDecl {
		var tMembers:Array<TClassMember> = [];
		var info:TInterfaceDeclInfo = {extend: null};
		if (i.extend != null) {
			structureSetups.push(() -> info.extend = typeClassImplement(mod, i.extend));
		}

		var tIface:TClassOrInterfaceDecl = {
			kind: TInterface(info),
			syntax: {
				keyword: i.keyword,
				name: i.name,
				openBrace: i.openBrace,
				closeBrace: i.closeBrace,
			},
			parentModule: mod,
			name: i.name.text,
			metadata: typeMetadata(i.metadata),
			modifiers: i.modifiers,
			members: tMembers
		};

		structureSetups.push(function() {
			var typerContext = makeTyperContext(mod, tIface);
			function loop(members:Array<InterfaceMember>) {
				for (m in members) {
					switch (m) {
						case MICondComp(v, openBrace, members, closeBrace):
							tMembers.push(TMCondCompBegin({v: ExprTyper.typeCondCompVar(v), openBrace: openBrace}));
							loop(members);
							tMembers.push(TMCondCompEnd({closeBrace: closeBrace}));
						case MIField(f):
							tMembers.push(TMField(typeInterfaceField(mod, f, typerContext)));
					}
				}
			}
			loop(i.members);
		});

		return tIface;
	}

	function typeInterfaceField(mod:TModule, f:InterfaceField, typerContext:ExprTyper.TyperContext):TClassField {
		var haxeType = HaxeTypeAnnotation.extractFromInterfaceField(f);

		var kind = switch (f.kind) {
			case IFFun(keyword, name, sig):
				var sig = typeFunctionSignature(sig, haxeType, typerContext);
				TFFun({
					syntax: {
						keyword: keyword,
						name: name,
					},
					name: name.text,
					fun: {sig: sig, expr: null},
					type: getFunctionTypeFromSignature(sig),
					isInline: false,
					semicolon: f.semicolon
				});
			case IFGetter(keyword, get, name, sig):
				var sig = typeFunctionSignature(sig, haxeType, typerContext);
				TFGetter({
					syntax: {
						functionKeyword: keyword,
						accessorKeyword: get,
						name: name,
					},
					name: name.text,
					propertyType: sig.ret.type,
					haxeProperty: null,
					fun: {sig: sig, expr: null},
					isInline: false,
					semicolon: f.semicolon
				});
			case IFSetter(keyword, set, name, sig):
				var sig = typeFunctionSignature(sig, haxeType, typerContext);
				TFSetter({
					syntax: {
						functionKeyword: keyword,
						accessorKeyword: set,
						name: name,
					},
					name: name.text,
					propertyType: sig.args[0].type,
					haxeProperty: null,
					fun: {sig: sig, expr: null},
					isInline: false,
					semicolon: f.semicolon
				});
		}
		return {
			modifiers: [],
			namespace: null,
			metadata: typeMetadata(f.metadata),
			kind: kind
		};
	}

	inline function err(mod:TModule, msg:String, pos:Int) context.reportError(mod.path, pos, msg);

	inline function throwErr(mod:TModule, msg:String, pos:Int):Dynamic {
		err(mod, msg, pos);
		throw "assert"; // TODO do it nicer
	}

	function typeFunctionSignature(sig:FunctionSignature, haxeType:Null<HaxeTypeAnnotation>, typerContext:ExprTyper.TyperContext):TFunctionSignature {
		var typeOverrides = typerContext.haxeTypes.resolveSignature(haxeType, sig.openParen.pos);

		var targs =
			if (sig.args != null) {
				separatedToArray(sig.args, function(arg, comma) {
					return switch (arg) {
						case ArgNormal(a):
							var typeOverride = if (typeOverrides == null) null else typeOverrides.args[a.name.text];

							var type:TType = if (typeOverride != null) typeOverride else if (a.type == null) TTAny else typerContext.resolveType(a.type.type);
							var init:Null<TVarInit>;
							if (a.init == null) {
								init = null;
							} else {
								init = {
									equalsToken: a.init.equalsToken,
									expr: null
								};
								exprTypings.push(() -> init.expr = new ExprTyper(context, tree, typerContext).typeExpr(a.init.expr, type));
							}
							{syntax: {name: a.name}, name: a.name.text, type: type, kind: TArgNormal(a.type, init), v: null, comma: comma};

						case ArgRest(dots, name, typeHint):
							{syntax: {name: name}, name: name.text, type: tUntypedArray, kind: TArgRest(dots, TRestAs3, typeHint), v: null, comma: comma};
					}
				});
			} else {
				[];
			};

		var returnTypeOverride = if (typeOverrides == null) null else typeOverrides.ret;

		var tret:TTypeHint;
		if (sig.ret != null) {
			tret = {
				type: if (returnTypeOverride != null) returnTypeOverride else typerContext.resolveType(sig.ret.type),
				syntax: sig.ret
			};
		} else {
			tret = {type: if (returnTypeOverride != null) returnTypeOverride else TTAny, syntax: null};
		}

		return {
			syntax: {
				openParen: sig.openParen,
				closeParen: sig.closeParen,
			},
			args: targs,
			ret: tret,
		};
	}

	function resolveType(mod:TModule, t:SyntaxType):TType {
		return switch (t) {
			case TAny(_):
				TTAny;
			case TPath(path):
				switch dotPathToArray(path) {
					case ["void"]: TTVoid;
					case ["Boolean"]: TTBoolean;
					case ["Number"]: TTNumber;
					case ["int"]: TTInt;
					case ["uint"]: TTUint;
					case ["String"]: TTString;
					case ["Array"]: tUntypedArray;
					case ["Object"]: tUntypedObject;
					case ["Class"]: TTClass;
					case ["Function"]: TTFunction;
					case ["XML"]: TTXML;
					case ["XMLList"]: TTXMLList;
					case ["RegExp"]: TTRegExp;
					case ['Namespace']: TTAny;
					case path: TypedTree.declToInst(resolveDotPath(mod, path));
				}
			case TVector(v):
				TTVector(resolveType(mod, v.t.type));
		}
	}

	function resolveDotPath(mod:TModule, path:Array<String>):TDecl {
		var name = path.pop();

		// fully qualified
		if (path.length > 0) {
			return tree.getDecl(path.join("."), name);
		}

		// current main decl
		if (mod.pack.decl.name == name) {
			return mod.pack.decl;
		}

		// current private decls
		for (decl in mod.privateDecls) {
			if (decl.name == name) {
				return decl;
			}
		}

		// imported decls
		for (i in mod.pack.imports) {
			switch (i.kind) {
				case TIAliased(d, as, alias):
					if (alias.text == name) return d;
				case TIDecl(d):
					if (d.name == name) return d;
				case TIAll(pack, _):
					for (m in pack) {
						if (m.name == name) return m.pack.decl;
					}
			}
		}

		// decls from the current package
		for (m in mod.parentPack) {
			if (m.name == name) return m.pack.decl;
		}

		// toplevel decls
		var rootPack = tree.getPackageOrNull("");
		if (rootPack != null) {
			for (m in rootPack) {
				if (m.name == name) return m.pack.decl;
			}
		}

		throw 'Unknown type: $name';
	}

	function typeImports(file:File, mod:TModule):Array<TImport> {
		inline function getPackage(name, pos) return try tree.getPackage(name) catch (e:Any) throwErr(mod, Std.string(e), pos);
		inline function getDecl(pack, name, pos) return try tree.getDecl(pack, name) catch (e:Any) throwErr(mod, Std.string(e), pos);

		var result = new Array<TImport>();
		function loop(decls:Array<Declaration>, condCompBegin:Null<TCondCompBegin>, condCompEnd:Null<TCondCompEnd>) {
			var len = decls.length;
			for (i in 0...len) {
				switch (decls[i]) {
					case DPackage(p): loop(p.declarations, null, null);
					case DImport(imp):
						var condCompBegin = if (i == 0) condCompBegin else null;
						var condCompEnd = if (i == len - 1) condCompEnd else null;
						var importKind;
						switch imp.wildcard {
							case null:
								var parts = dotPathToArray(imp.path);
								var name:String = @:nullSafety(Off) parts.pop();
								var packName = parts.join(".");
								var decl = getDecl(packName, name, imp.keyword.pos);
								importKind = TIDecl(decl);

							case w:
								var pack = getPackage(dotPathToString(imp.path), imp.keyword.pos);
								importKind = TIAll(pack, w.dot, w.asterisk);
						}
						result.push({
							syntax: {
								condCompBegin: condCompBegin,
								keyword: imp.keyword,
								path: imp.path,
								semicolon: imp.semicolon,
								condCompEnd: condCompEnd
							},
							kind: importKind
						});
					case DCondComp(v, openBrace, decls, closeBrace): loop(decls, {v: ExprTyper.typeCondCompVar(v), openBrace: openBrace}, {closeBrace: closeBrace});
					case _:
				}
			}
		}
		loop(file.declarations, null, null);
		return result;
	}

}
