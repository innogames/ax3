package ax3;

import ax3.ParseTree;
import ax3.Token;
import ax3.TypedTreeTools.tUntypedDictionary;
import ax3.TypedTreeTools.isFieldStatic;

typedef PackageName = String;
typedef ModuleName = String;

class TypedTree {
	public final packages = new Map<PackageName,TPackage>();

	public function new() {}

	public function getPackage(packName:String):TPackage {
		var pack = getPackageOrNull(packName);
		if (pack == null) throw 'No such package $packName';
		return pack;
	}

	public inline function getPackageOrNull(packName:String):Null<TPackage> {
		return packages[packName];
	}

	public function getDecl(packName:String, name:String):TDecl {
		var mod = getPackage(packName).getModule(name);
		if (mod == null) throw 'No such module $packName::$name';
		return mod.pack.decl;
	}

	public function getType(s: String): TType {
		s = StringTools.trim(s);
		final i = s.indexOf('<');
		return i == -1 ? switch s {
			case 'void': TTVoid;
			case 'Boolean': TTBoolean;
			case 'Number': TTNumber;
			case 'int': TTInt;
			case 'uint': TTUint;
			case 'String': TTString;
			case 'Class': TTClass;
			case 'Function': TTFunction;
			case 'XML': TTXML;
			case 'XMLList': TTXMLList;
			case 'RegExp': TTRegExp;
			case _: TTInst(getByFullName(s));
		} : switch s.substr(0, i) {
			case 'Array': TTArray(getType(s.substring(i + 1, s.lastIndexOf('>'))));
			case 'Object': TTObject(getType(s.substring(i + 1, s.lastIndexOf('>'))));
			case 'Dictionary':
				final comma = s.indexOf(',');
				TTDictionary(getType(s.substring(i + 1, comma)), getType(s.substring(comma + 1, s.lastIndexOf('>'))));
			case _: throw 'Not supported type: $s';
		}
	}

	public function getByFullName(name: String): TClassOrInterfaceDecl {
		final i = name.lastIndexOf('.');
		return getClassOrInterface(name.substring(0, i), name.substring(i + 1));
	}

	public function getClassOrInterface(packName:String, name:String):TClassOrInterfaceDecl {
		return switch getDecl(packName, name).kind {
			case TDClassOrInterface(c): c;
			case _: throw '$packName::$name is not a class or interface';
		};
	}

	public function getInterface(packName:String, name:String):TClassOrInterfaceDecl {
		return switch getDecl(packName, name).kind {
			case TDClassOrInterface(iface) if (iface.kind.match(TInterface(_))): iface;
			case _: throw '$packName::$name is not an interface';
		}
	}

	public function getOrCreatePackage(packName:PackageName):TPackage {
		return switch packages[packName] {
			case null: packages[packName] = new TPackage(packName);
			case pack: pack;
		};
	}

	public static function declToInst(decl:TDecl):TType {
		return switch decl.kind {
			case TDClassOrInterface({name: "Dictionary"}): tUntypedDictionary; // TODO: check package
			case TDClassOrInterface(c): TTInst(c);
			case _: throw "assert";
		}
	}

	public static function declToStatic(decl:TDecl):TType {
		return switch decl.kind {
			case TDClassOrInterface(c): TTStatic(c);
			case _: throw "assert";
		}
	}

	public function dump() {
		return [for (name => pack in packages) pack.dump(name)].join("\n\n\n");
	}
}

class TPackage {
	public final name:String;

	final modules = new Map<ModuleName,TModule>();

	public function new(name) {
		this.name = name;
	}

	public inline function iterator() return modules.iterator();

	public inline function getModule(moduleName:ModuleName):Null<TModule> {
		return modules[moduleName];
	}

	public inline function addModule(module:TModule) {
		if (modules.exists(module.name)) throw 'Module ${module.name} is already defined!';
		modules[module.name] = module;
	}

	public inline function replaceModule(module:TModule) {
		modules[module.name] = module;
	}

	public inline function renameModule(module:TModule, newName:String) {
		if (modules.exists(newName)) throw 'Module $newName already exists!';
		modules.remove(module.name);
		modules[newName] = module;
		module.name = newName;
	}

	public function dump(name:String) {
		return (if (name == "") "<root>" else name) + "\n" + [for (name => module in modules) dumpModule(name, module)].join("\n\n");
	}

	static final indent = "  ";

	static function dumpModule(name:String, m:TModule) {
		var r = [indent + name];
		if (m.pack.decl != null) {
			r.push(indent + indent + "MAIN:");
			r.push(dumpDecl(m.pack.decl));
		}
		if (m.privateDecls.length > 0) {
			r.push(indent + indent + "PRIVATE:");
			for (d in m.privateDecls) {
				r.push(dumpDecl(d));
			}
		}
		return r.join("\n");
	}

	static function dumpDecl(d:TDecl):String {
		var indent = indent + indent + indent;
		switch (d.kind) {
			case TDVar(v):
				return indent + dumpVar("VAR", v.name, v.type);
			case TDFunction(f):
				return indent + dumpFun(f.name, f.fun.sig);
			case TDNamespace({name: {text: name}}):
				return indent + "NS " + name;
			case TDClassOrInterface(cls):
				var r = [];
				switch cls.kind {
					case TInterface(info):
						r.push(indent + "IFACE " + cls.name);
						if (info.extend != null) {
							r.push(indent + " - EXT: " + [for (i in info.extend.interfaces) i.iface.decl.name].join(", "));
						}
					case TClass(info):
						r.push(indent + "CLS " + cls.name);
						if (info.extend != null) {
							r.push(indent + " - EXT: " + info.extend.superClass.name);
						}
				}
				for (m in cls.members) {
					switch (m) {
						case TMField(f): r.push(dumpClassField(f));
						case TMCondCompBegin(_) | TMCondCompEnd(_):
						case TMStaticInit(_) | TMUseNamespace(_):
					}
				}
				return r.join("\n");
		}
	}

	static function dumpVar(prefix:String, name:String, type:TType):String {
		return prefix + " " + name + ":" + dumpType(type);
	}

	static function dumpFun(name:String, f:TFunctionSignature):String {
		var args = [for (a in f.args) switch (a.kind) {
			case TArgNormal(_, init): (if (init != null) "?" else "") + a.name + ":" + dumpType(a.type);
			case TArgRest(_): "..." + a.name;
		}];
		return "FUN " + name + "(" + args.join(", ") + "):" + dumpType(f.ret.type);
	}

	static function dumpClassField(f:TClassField):String {
		var prefix = indent + indent + indent + indent;
		return switch (f.kind) {
			case TFFun(f): prefix + dumpFun(f.name, f.fun.sig);
			case TFVar(f): prefix + dumpVar("VAR", f.name, f.type);
			case TFGetter(f): prefix + dumpVar("GET", f.name, f.propertyType);
			case TFSetter(f): prefix + dumpVar("SET", f.name, f.propertyType);
		};
	}

	static function dumpType(t:TType):String {
		return switch (t) {
			case TTVoid: "void";
			case TTAny: "*";
			case TTBoolean: "Boolean";
			case TTNumber: "Number";
			case TTInt: "int";
			case TTUint: "uint";
			case TTString: "String";
			case TTArray(_): "Array";
			case TTObject(_): "Object";
			case TTDictionary(_): "Dictionary";
			case TTFunction | TTFun(_): "Function";
			case TTClass: "Class";
			case TTXML: "XML";
			case TTXMLList: "XMLList";
			case TTRegExp: "RegExp";
			case TTVector(t): "Vector.<" + dumpType(t) + ">";
			case TTInst(cls): cls.name;
			case TTStatic(cls): "Class<"+cls.name+">";
			case TTBuiltin: "BUILTIN";
		}
	}
}

@:structInit @:publicFields
class TModule {
	var isExtern:Bool;
	var path:String;
	var parentPack:TPackage;
	var pack:TPackageDecl;
	var name:String;
	var privateDecls:Array<TDecl>;
	var eof:Token;

	static function isClassDecl(decl:TDecl, c:TClassOrInterfaceDecl):Bool {
		return switch decl {
			case {kind: TDClassOrInterface(otherClass)} if (otherClass == c): true;
			case _: false;
		};
	}

	function isImported(c:TClassOrInterfaceDecl) {
		if (isClassDecl(pack.decl, c)) {
			return true;
		}
		for (decl in privateDecls) {
			if (isClassDecl(decl, c)) {
				return true;
			}
		}

		// TODO: optimize this, because this is done A LOT
		// actually, we might want to store the "local" flag in the TEDeclRef/TTypeHint/etc.
		var i = pack.imports.length;
		while (i-- > 0) {
			var imp = pack.imports[i];
			switch imp.kind {
				case TIDecl({kind: TDClassOrInterface(importedClass)}):
					if (importedClass == c) {
						return true;
					} else if (importedClass.name == c.name) {
						// the imported class name overshadows this class, so we can't refer this class by unqialified name
						return false;
					}

				case TIAll(pack, _):
					for (mod in pack) {
						switch mod.pack.decl.kind {
							case TDClassOrInterface(importedClass) if (importedClass == c):
								return true;

							case _:
						}
					}

				case TIDecl(_) | TIAliased(_): // other decls and aliased decls
			}
		}
		for (mod in parentPack) {
			switch mod.pack.decl.kind {
				case TDClassOrInterface(importedClass) if (importedClass == c):
					return true;
				case _:
			}
		}
		return false;
	}
}

typedef TPackageDecl = {
	var syntax:{
		var keyword:Token;
		var name:Null<DotPath>;
		var openBrace:Token;
		var closeBrace:Token;
	};
	var imports:Array<TImport>;
	var namespaceUses:Array<{n:UseNamespace, semicolon:Token}>;
	var name:String;
	var decl:TDecl;
}

typedef TImport = {
	var syntax:{
		var condCompBegin:Null<TCondCompBegin>;
		var keyword:Token;
		var path:DotPath;
		var semicolon:Token;
		var condCompEnd:Null<TCondCompEnd>;
	}
	var kind:TImportKind;
}

enum TImportKind {
	TIDecl(d:TDecl);
	TIAliased(d:TDecl, as:Token, name:Token);
	TIAll(pack:TPackage, dot:Token, asterisk:Token);
}

typedef TCondCompBegin = {
	var v:TCondCompVar;
	var openBrace:Token;
}

typedef TCondCompEnd = {closeBrace:Token}

typedef TDecl = {
	var name:String;
	var kind:TDeclKind;
}

enum TDeclKind {
	TDClassOrInterface(c:TClassOrInterfaceDecl);
	TDVar(v:TModuleVarDecl);
	TDFunction(v:TFunctionDecl);
	TDNamespace(n:NamespaceDecl);
}

typedef TFunctionDecl = {
	var metadata:Array<TMetadata>;
	var modifiers:Array<DeclModifier>;
	var syntax:{keyword:Token, name:Token};
	var name:String;
	var parentModule:TModule;
	var fun:TFunction;
}

typedef TModuleVarDecl = TVarField & {
	var metadata:Array<TMetadata>;
	var modifiers:Array<DeclModifier>;
	var parentModule:TModule;
}

@:structInit @:publicFields
class TClassOrInterfaceDecl {
	var syntax:{
		var keyword:Token;
		var name:Token;
		var openBrace:Token;
		var closeBrace:Token;
	};
	var kind:TDClassOrInterfaceKind;
	var metadata:Array<TMetadata>;
	var modifiers:Array<DeclModifier>;
	var parentModule:TModule;
	var name:String;
	var members:Array<TClassMember>;

	function toString():String {
		return parentModule.parentPack.name + "::" + name;
	}

	function findField(name:String, findStatic:Null<Bool>):Null<TClassField> {
		for (member in members) {
			switch (member) {
				case TMField(classField):
					if (findStatic != null && findStatic != isFieldStatic(classField)) {
						continue;
					}
					switch classField.kind {
						case TFFun(fun):
							if (fun.name == name) {
								return classField;
							}
						case TFVar(v):
							if (v.name == name) {
								return classField;
							}
						case TFGetter(a) | TFSetter(a):
							if (a.name == name) {
								return classField;
							}
					}
				case TMUseNamespace(_) | TMCondCompBegin(_) | TMCondCompEnd(_) | TMStaticInit(_):
			}
		}
		return null;
	}

	function findFieldInHierarchy(name:String, findStatic:Null<Bool>):Null<{field:TClassField, declaringClass:TClassOrInterfaceDecl}> {
		function loop(cls:TClassOrInterfaceDecl) {
			var field = cls.findField(name, findStatic);
			if (field != null) {
				return {field: field, declaringClass: cls};
			}
			switch cls.kind {
				case TInterface(info):
					if (info.extend != null) {
						for (h in info.extend.interfaces) {
							var field = loop(h.iface.decl);
							if (field != null) {
								return field;
							}
						}
					}
				case TClass(info):
					if (info.extend != null) {
						return loop(info.extend.superClass);
					}
			}
			return null;
		}
		return loop(this);
	}
}

enum TDClassOrInterfaceKind {
	TInterface(info:TInterfaceDeclInfo);
	TClass(info:TClassDeclInfo);
}

typedef TInterfaceDeclInfo = {
	var extend:Null<TClassImplement>;
}

typedef TClassDeclInfo = {
	var extend:Null<TClassExtend>;
	var implement:Null<TClassImplement>;
}

typedef TClassExtend = {
	var syntax:{
		var keyword:Token;
		var path:DotPath;
	};
	var superClass:TClassOrInterfaceDecl;
}

typedef TClassImplement = {
	var keyword:Token;
	var interfaces:Array<{iface:TInterfaceHeritage, comma:Null<Token>}>;
}

typedef TInterfaceHeritage = {
	var syntax:DotPath;
	var decl:TClassOrInterfaceDecl;
}

enum TClassMember {
	TMUseNamespace(n:UseNamespace, semicolon:Token);
	TMCondCompBegin(b:TCondCompBegin);
	TMCondCompEnd(b:TCondCompEnd);
	TMField(f:TClassField);
	TMStaticInit(i:{expr:TExpr});
}

typedef TClassField = {
	var metadata:Array<TMetadata>;
	var namespace:Null<Token>;
	var modifiers:Array<ClassFieldModifier>;
	var kind:TClassFieldKind;
}

enum TMetadata {
	MetaFlash(m:Metadata);
	MetaHaxe(t:Token, args:Null<CallArgs>);
}

enum TClassFieldKind {
	TFVar(f:TVarField);
	TFFun(f:TFunctionField);
	TFGetter(f:TAccessorField);
	TFSetter(f:TAccessorField);
}

typedef THaxePropDecl = {
	var syntax:{
		var leadTrivia:Array<Trivia>; // for indentation
	}
	var metadata:Array<TMetadata>;
	var isPublic:Bool;
	var isStatic:Bool;
	var isFlashProperty:Bool;
	var name:String;
	var get:Bool;
	var set:Bool;
	var type:TType;
}

typedef TFunctionField = {
	var syntax:{
		var keyword:Token;
		var name:Token;
	};
	var name:String;
	var fun:TFunction;
	var type:TType;
	var isInline:Bool;
	var semicolon:Null<Token>;
}

typedef TAccessorField = {
	var syntax:{
		var functionKeyword:Token;
		var accessorKeyword:Token;
		var name:Token;
	}
	var name:String;
	var fun:TFunction;
	var propertyType:TType;
	var haxeProperty:Null<THaxePropDecl>;
	var isInline:Bool;
	var semicolon:Null<Token>;
}

typedef TVarField = {
	var kind:VarDeclKind;
	var syntax:{
		var name:Token;
		var type:Null<TypeHint>;
	}
	var name:String;
	var type:TType;
	var init:Null<TVarInit>;
	var semicolon:Token;
	var isInline:Bool;
}

typedef TExpr = {
	var kind:TExprKind;
	var type:TType;
	var expectedType:TType;
}

enum TExprKind {
	TEParens(openParen:Token, e:TExpr, closeParen:Token);
	TELocalFunction(f:TLocalFunction);
	TELiteral(l:TLiteral);
	TELocal(syntax:Token, v:TVar);
	TEField(obj:TFieldObject, fieldName:String, fieldToken:Token);
	TEBuiltin(syntax:Token, name:String);
	TEDeclRef(path:DotPath, c:TDecl);
	TECall(eobj:TExpr, args:TCallArgs);
	TECast(c:TCast);
	TEArrayDecl(a:TArrayDecl);
	TEVectorDecl(v:TVectorDecl);
	TEReturn(keyword:Token, e:Null<TExpr>);
	TETypeof(keyword:Token, e:TExpr);
	TEThrow(keyword:Token, e:TExpr);
	TEDelete(keyword:Token, e:TExpr);
	TEBreak(keyword:Token);
	TEContinue(keyword:Token);
	TEVars(kind:VarDeclKind, vars:Array<TVarDecl>);
	TEObjectDecl(o:TObjectDecl);
	TEArrayAccess(a:TArrayAccess);
	TEBlock(block:TBlock);
	TETry(t:TTry);
	TEVector(syntax:VectorSyntax, type:TType);
	TETernary(t:TTernary);
	TEIf(i:TIf);
	TEWhile(w:TWhile);
	TEDoWhile(w:TDoWhile);
	TEFor(f:TFor);
	TEForIn(f:TForIn);
	TEForEach(f:TForEach);
	TEHaxeFor(f:THaxeFor);
	TEBinop(a:TExpr, op:Binop, b:TExpr);
	TEPreUnop(op:PreUnop, e:TExpr);
	TEPostUnop(e:TExpr, op:PostUnop);
	TEAs(e:TExpr, keyword:Token, type:TTypeRef);
	TESwitch(s:TSwitch);
	TENew(keyword:Token, cls:TNewObject, args:Null<TCallArgs>);
	TECondCompValue(v:TCondCompVar);
	TECondCompBlock(v:TCondCompVar, expr:TExpr);
	TEXmlChild(x:TXmlChild);
	TEXmlAttr(x:TXmlAttr);
	TEXmlAttrExpr(x:TXmlAttrExpr);
	TEXmlDescend(x:TXmlDescend);
	TEUseNamespace(ns:UseNamespace);
	TEHaxeRetype(e:TExpr);
	TEHaxeIntIter(start:TExpr, end:TExpr);
}

enum TNewObject {
	TNType(t:TTypeRef);
	TNExpr(e:TExpr);
}

typedef TCast = {
	var syntax:{
		var openParen:Token;
		var closeParen:Token;
		var path:DotPath;
	};
	var expr:TExpr;
	var type:TType;
}

typedef TLocalFunction = {
	var syntax:{keyword:Token};
	var name:Null<{syntax:Token, name:String}>;
	var fun:TFunction;
}

typedef TXmlDescend = {
	var syntax:{
		var dotDot:Token;
		var name:Token;
	};
	var eobj:TExpr;
	var name:String;
}

typedef TXmlChild = {
	var syntax:{
		var dot:Token;
		var name:Token;
	};
	var eobj:TExpr;
	var name:String;
}
typedef TXmlAttr = {
	var syntax:{
		var dot:Token;
		var at:Token;
		var name:Token;
	};
	var eobj:TExpr;
	var name:String;
}

typedef TXmlAttrExpr = {
	var syntax:{
		var dot:Token;
		var at:Token;
		var openBracket:Token;
		var closeBracket:Token;
	};
	var eobj:TExpr;
	var eattr:TExpr;
}
typedef TVectorDecl = {
	var syntax:{
		var newKeyword:Token;
		var typeParam:TypeParam;
	}
	var elements:TArrayDecl;
	var type:TType;
}

typedef TCondCompVar = {
	var syntax:CondCompVar;
	var ns:String;
	var name:String;
}

typedef TArrayDecl = {
	var syntax:{
		var openBracket:Token;
		var closeBracket:Token;
	};
	var elements:Array<{expr:TExpr, comma:Null<Token>}>;
}

typedef TWhile = {
	var syntax:{
		var keyword:Token;
		var openParen:Token;
		var closeParen:Token;
	};
	var cond:TExpr;
	var body:TExpr;
}

typedef TDoWhile = {
	var syntax:{
		var doKeyword:Token;
		var whileKeyword:Token;
		var openParen:Token;
		var closeParen:Token;
	};
	var body:TExpr;
	var cond:TExpr;
}

typedef TFor = {
	var syntax:{
		var keyword:Token;
		var openParen:Token;
		var initSep:Token;
		var condSep:Token;
		var closeParen:Token;
	}
	var einit:Null<TExpr>;
	var econd:Null<TExpr>;
	var eincr:Null<TExpr>;
	var body:TExpr;
}

typedef TForIn = {
	var syntax:{
		var forKeyword:Token;
		var openParen:Token;
		var closeParen:Token;
	}
	var iter:TForInIter;
	var body:TExpr;
}

typedef TForEach = {
	var syntax:{
		var forKeyword:Token;
		var eachKeyword:Token;
		var openParen:Token;
		var closeParen:Token;
	}
	var iter:TForInIter;
	var body:TExpr;
}

typedef THaxeFor = {
	var syntax:{
		var forKeyword:Token;
		var openParen:Token;
		var itName:Token;
		var inKeyword:Token;
		var closeParen:Token;
	};
	var vit:TVar;
	var iter:TExpr;
	var body:TExpr;
}

typedef TForInIter = {
	var eit:TExpr;
	var inKeyword:Token;
	var eobj:TExpr;
}

typedef TTernary = {
	var syntax:{
		question:Token,
		colon:Token,
	};
	var econd:TExpr;
	var ethen:TExpr;
	var eelse:TExpr;
}


typedef TIf = {
	var syntax:{
		keyword:Token,
		openParen:Token,
		closeParen:Token,
	};
	var econd:TExpr;
	var ethen:TExpr;
	var eelse:Null<{keyword:Token, expr:TExpr, semiliconBefore: Bool}>;
}

typedef TCallArgs = {
	var openParen:Token;
	var args:Array<{expr:TExpr, comma:Null<Token>}>;
	var closeParen:Token;
}

typedef TArrayAccess = {
	var syntax:{openBracket:Token, closeBracket:Token};
	var eobj:TExpr;
	var eindex:TExpr;
}

typedef TObjectDecl = {
	var syntax:{openBrace:Token, closeBrace:Token};
	var fields:Array<TObjectField>;
}

typedef TFieldObject = {
	var type:TType;
	var kind:TFieldObjectKind;
}

enum TFieldObjectKind {
	TOImplicitThis(c:TClassOrInterfaceDecl);
	TOImplicitClass(c:TClassOrInterfaceDecl);
	TOExplicit(dot:Token, e:TExpr);
}

typedef TBlock = {
	var syntax:{openBrace:Token, closeBrace:Token};
	var exprs:Array<TBlockExpr>;
}

typedef TBlockExpr = {
	var expr:TExpr;
	var semicolon:Null<Token>;
}

typedef TFunction = {
	var sig:TFunctionSignature;
	var expr:TExpr;
}

typedef TFunctionSignature = {
	var syntax:{
		var openParen:Token;
		var closeParen:Token;
	};
	var args:Array<TFunctionArg>;
	var ret:TTypeHint;
}

typedef TTypeHint = {
	var syntax:Null<TypeHint>;
	var type:TType;
}

typedef TTypeRef = {
	var type:TType;
	var syntax:SyntaxType;
}

typedef TFunctionArg = {
	var syntax:{
		var name:Token;
	}
	var name:String;
	var type:TType;
	var v:Null<TVar>;
	var kind:TFunctionArgKind;
	var comma:Null<Token>;
}

enum TFunctionArgKind {
	TArgNormal(typeHint:Null<TypeHint>, init:Null<TVarInit>);
	TArgRest(dots:Token, kind:TRestKind, typeHint:Null<TypeHint>);
}

typedef TSwitch = {
	var syntax:{
		var keyword:Token;
		var openParen:Token;
		var closeParen:Token;
		var openBrace:Token;
		var closeBrace:Token;
	}
	var subj:TExpr;
	var cases:Array<TSwitchCase>;
	var def:Null<TSwitchDefault>;
}

typedef TSwitchCase = {
	var syntax:{
		var keyword:Token;
		var colon:Token;
	}
	var values:Array<TExpr>;
	var body:Array<TBlockExpr>;
}

typedef TSwitchDefault = {
	var syntax:{
		var keyword:Token;
		var colon:Token;
	}
	var body:Array<TBlockExpr>;
}

typedef TTry = {
	var keyword:Token;
	var expr:TExpr;
	var catches:Array<TCatch>;
}

typedef TCatch = {
	var syntax:{
		var keyword:Token;
		var openParen:Token;
		var name:Token;
		var type:TypeHint;
		var closeParen:Token;
	};
	var v:TVar;
	var expr:TExpr;
}

typedef TObjectField = {
	var syntax:{name:Token, nameKind:ObjectFieldNameKind, colon:Token, comma:Null<Token>};
	var name:String;
	var expr:TExpr;
}

typedef TVarDecl = {
	var syntax:{
		var name:Token;
		var type:Null<TypeHint>;
	}
	var v:TVar;
	var init:Null<TVarInit>;
	var comma:Null<Token>;
}

typedef TVarInit = {
	var equalsToken:Token;
	var expr:TExpr;
}

enum TLiteral {
	TLThis(syntax:Token);
	TLSuper(syntax:Token);
	TLBool(syntax:Token);
	TLNull(syntax:Token);
	TLUndefined(syntax:Token);
	TLInt(syntax:Token);
	TLNumber(syntax:Token);
	TLString(syntax:Token);
	TLRegExp(syntax:Token);
}

typedef TVar = {
	var name:String;
	var type:TType;
}

enum TType {
	TTVoid;
	TTAny; // *
	TTBoolean;
	TTNumber;
	TTInt;
	TTUint;
	TTString;
	TTArray(t:TType);
	TTDictionary(k:TType, v:TType);
	TTFunction;
	TTClass;
	TTObject(t:TType);
	TTXML;
	TTXMLList;
	TTRegExp;
	TTVector(t:TType);

	TTBuiltin; // TODO: temporary

	TTFun(args:Array<TType>, ret:TType, ?rest:Null<TRestKind>); // method and local function refs
	TTInst(i:TClassOrInterfaceDecl); // class instance access (`obj` in `obj.some`)
	TTStatic(cls:TClassOrInterfaceDecl); // class statics access (`Cls` in `Cls.some`)
}

enum TRestKind {
	TRestSwc;
	TRestAs3;
}
