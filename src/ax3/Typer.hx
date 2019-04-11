package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;
import ax3.TypedTree;
import ax3.TypedTreeTools.tUntypedArray;
import ax3.TypedTreeTools.tUntypedObject;
import ax3.TypedTreeTools.tUntypedDictionary;
import ax3.HaxeTypeAnnotation;

class Typer {
	public static function process(tree:TypedTree, files:Array<File>) {
		var typer = new Typer(tree);
		for (file in files) {
			typer.processFile(file);
		}
		for (f in typer.importSetups) f();
		for (f in typer.heritageSetups) f();
		for (f in typer.structureSetups) f();
		for (f in typer.exprTypings) f();
	}

	final tree:TypedTree;

	final importSetups:Array<()->Void> = [];
	final heritageSetups:Array<()->Void> = [];
	final structureSetups:Array<()->Void> = [];
	final exprTypings:Array<()->Void> = [];

	function new(tree) {
		this.tree = tree;
	}

	function processFile(file:File) {
		var pack = getPackageDecl(file);
		var packName = if (pack.name == null) "" else dotPathToString(pack.name);

		var tModule:TModule = {
			path: file.path,
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

		importSetups.push(() -> tModule.pack.imports = typeImports(file));

		tModule.pack.decl = typeDecl(getPackageMainDecl(pack), tModule);
		for (decl in getPrivateDecls(file)) {
			tModule.privateDecls.push(typeDecl(decl, tModule));
		}

		tree.getOrCreatePackage(packName).replaceModule(tModule);
	}

	function typeDecl(d:Declaration, mod:TModule):TDecl {
		return switch (d) {
			case DPackage(_) | DImport(_) | DUseNamespace(_): throw "assert";
			// case DClass(c):
			// 	TDClass(typeClass(c));
			case DInterface(i):
				{name: i.name.text, kind: TDInterface(typeInterface(i, mod))};
			// case DFunction(f):
			// 	TDFunction(typeModuleFunction(f));
			// case DVar(v):
			// 	TDVar(typeModuleVars(v));
			case DNamespace(ns):
				{name: null, kind: TDNamespace(ns)};
			case DCondComp(v, openBrace, decls, closeBrace): throw "TODO";
			case _: null;
		}
	}

	function typeInterface(i:InterfaceDecl, mod:TModule):TInterfaceDecl {
		var tMembers:Array<TInterfaceMember> = [];

		var iface:TInterfaceDecl = {
			syntax: {
				keyword: i.keyword,
				name: i.name,
				openBrace: i.openBrace,
				closeBrace: i.closeBrace,
			},
			name: i.name.text,
			extend: null,
			metadata: i.metadata,
			modifiers: i.modifiers,
			members: tMembers,
		}

		if (i.extend != null) {
			heritageSetups.push(function() {
				iface.extend = {
					syntax: {keyword: i.extend.keyword},
					interfaces: separatedToArray(i.extend.paths, function(path, comma) {
						var ifaceDecl = switch resolveDotPath(mod, dotPathToArray(path)).kind {
							case TDInterface(i): i;
							case _: throw "Not an interface";
						}
						return {iface: {syntax: path, decl: ifaceDecl}, comma: comma}
					})
				}
			});
		}

		structureSetups.push(function() {
			function loop(members:Array<InterfaceMember>) {
				for (m in members) {
					switch (m) {
						case MICondComp(v, openBrace, members, closeBrace):
							tMembers.push(TIMCondCompBegin({v: typeCondCompVar(v), openBrace: openBrace}));
							loop(members);
							tMembers.push(TIMCondCompEnd({closeBrace: closeBrace}));
						case MIField(f):
							tMembers.push(TIMField(typeInterfaceField(mod, f)));
					}
				}
			}
			loop(i.members);
		});

		return iface;
	}

	function typeInterfaceField(mod:TModule, f:InterfaceField):TInterfaceField {
		var haxeType = HaxeTypeAnnotation.extractFromInterfaceField(f);

		var kind = switch (f.kind) {
			case IFFun(keyword, name, sig):
				var sig = typeFunctionSignature(mod, sig, haxeType);
				TIFFun({
					syntax: {
						keyword: keyword,
						name: name,
					},
					name: name.text,
					sig: sig
				});
			case IFGetter(keyword, get, name, sig):
				var sig = typeFunctionSignature(mod, sig, haxeType);
				TIFGetter({
					syntax: {
						functionKeyword: keyword,
						accessorKeyword: get,
						name: name,
					},
					name: name.text,
					sig: sig
				});
			case IFSetter(keyword, set, name, sig):
				var sig = typeFunctionSignature(mod, sig, haxeType);
				TIFSetter({
					syntax: {
						functionKeyword: keyword,
						accessorKeyword: set,
						name: name,
					},
					name: name.text,
					sig: sig
				});
		}
		return {
			metadata: f.metadata,
			kind: kind,
			semicolon: f.semicolon
		};
	}

	function resolveHaxeType(mod:TModule, t:HaxeType, pos:Int):TType {
		return switch t {
			case HTPath("Array", [elemT]): TTArray(resolveHaxeType(mod, elemT, pos));
			case HTPath("Int", []): TTInt;
			case HTPath("UInt", []): TTUint;
			case HTPath("Float", []): TTNumber;
			case HTPath("Bool", []): TTBoolean;
			case HTPath("String", []): TTString;
			case HTPath("Dynamic", []): TTAny;
			case HTPath("Void", []): TTVoid;
			case HTPath("FastXML", []): TTXML;
			case HTPath("haxe.DynamicAccess", [elemT]): TTObject(resolveHaxeType(mod, elemT, pos));
			case HTPath("flash.utils.Object", []): tUntypedObject;
			case HTPath("Vector" | "flash.Vector", [t]): TTVector(resolveHaxeType(mod, t, pos));
			case HTPath("GenericDictionary", [k, v]): TTDictionary(resolveHaxeType(mod, k, pos), resolveHaxeType(mod, v, pos));
			case HTPath("Class", [HTPath("Dynamic", [])]): TTClass;
			case HTPath("Class", [HTPath(path, [])]): TypedTree.declToStatic(resolveDotPath(mod, path.split(".")));
			case HTPath("Null", [t]): resolveHaxeType(mod, t, pos); // TODO: keep nullability?
			case HTPath(path, []): TypedTree.declToInst(resolveDotPath(mod, path.split(".")));
			case HTPath(path, _): trace("TODO: " + path); TTAny;
			case HTFun(args, ret): TTFun([for (a in args) resolveHaxeType(mod, a, pos)], resolveHaxeType(mod, ret, pos));
		};
	}

	function resolveHaxeSignature(mod:TModule, a:Null<HaxeTypeAnnotation>, p:Int):Null<{args:Map<String,TType>, ret:Null<TType>}> {
		if (a == null) {
			return null;
		}
		var sig = a.parseSignature();
		return {
			args: [for (name => type in sig.args) name => resolveHaxeType(mod, type, p)],
			ret: if (sig.ret == null) null else resolveHaxeType(mod, sig.ret, p)
		};
	}

	function typeFunctionSignature(mod:TModule, sig:FunctionSignature, haxeType:Null<HaxeTypeAnnotation>):TFunctionSignature {
		var typeOverrides = resolveHaxeSignature(mod, haxeType, sig.openParen.pos);

		var targs =
			if (sig.args != null) {
				separatedToArray(sig.args, function(arg, comma) {
					return switch (arg) {
						case ArgNormal(a):
							var typeOverride = if (typeOverrides == null) null else typeOverrides.args[a.name.text];

							var type:TType = if (typeOverride != null) typeOverride else if (a.type == null) TTAny else resolveType(mod, a.type.type);
							var init:Null<TVarInit>;
							if (a.init == null) {
								init = null;
							} else {
								init = {
									equalsToken: a.init.equalsToken,
									expr: null
								};
								// exprTypings.push(() -> init.expr = typeExpr(a.init.expr));
							}
							{syntax: {name: a.name}, name: a.name.text, type: type, kind: TArgNormal(a.type, init), v: null, comma: comma};

						case ArgRest(dots, name):
							{syntax: {name: name}, name: name.text, type: tUntypedArray, kind: TArgRest(dots), v: null, comma: comma};
					}
				});
			} else {
				[];
			};

		var returnTypeOverride = if (typeOverrides == null) null else typeOverrides.ret;

		var tret:TTypeHint;
		if (sig.ret != null) {
			tret = {
				type: if (returnTypeOverride != null) returnTypeOverride else resolveType(mod, sig.ret.type),
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
					case path: TypedTree.declToInst(resolveDotPath(mod, path));
				}
			case TVector(v):
				TTVector(resolveType(mod, v.t.type));
		}
	}

	function resolveDotPath(mod:TModule, path:Array<String>):TDecl {
		var name = path.pop();
		if (path.length > 0) { // fully qualified
			return tree.getDecl(path.join("."), name);
		}

		if (mod.pack.decl.name == name) {
			return mod.pack.decl;
		}

		for (decl in mod.privateDecls) {
			if (decl.name == name) {
				return decl;
			}
		}

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

		var currentPack = tree.getPackage(mod.pack.name);
		for (m in currentPack) {
			if (m.name == name) return m.pack.decl;
		}

		var rootPack = tree.getPackageOrNull("");
		if (rootPack != null) {
			for (m in rootPack) {
				if (m.name == name) return m.pack.decl;
			}
		}

		throw 'Unknown type: $name';
	}

	function typeImports(file:File):Array<TImport> {
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
								var decl = tree.getDecl(packName, name);
								importKind = TIDecl(decl);

							case w:
								var pack = tree.getPackage(dotPathToString(imp.path));
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
					case DCondComp(v, openBrace, decls, closeBrace): loop(decls, {v: typeCondCompVar(v), openBrace: openBrace}, {closeBrace: closeBrace});
					case _:
				}
			}
		}
		loop(file.declarations, null, null);
		return result;
	}

	static function typeCondCompVar(v:CondCompVar):TCondCompVar {
		return {syntax: v, ns: v.ns.text, name: v.name.text};
	}
}
