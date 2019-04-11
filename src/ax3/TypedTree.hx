package ax3;

import ax3.ParseTree;
import ax3.Structure;
import ax3.Token;

typedef PackageName = String;
typedef ModuleName = String;

class TypedTree {
	final packages = new Map<PackageName,TPackage>();

	var delayedCalls:Array<()->Void> = [];

	public function new() {}

	public inline function delay(f:()->Void) {
		delayedCalls.push(f);
	}

	public function flush() {
		for (f in delayedCalls) f();
		delayedCalls = [];
	}

	public function getDecl(packName:String, name:String):TDecl {
		var pack = packages[packName];
		if (pack == null) throw 'No such package $packName';
		var mod = pack.getModule(name);
		if (mod == null) throw 'No such module $packName::$name';
		return mod.pack.decl;
	}

	public function getInterface(packName:String, name:String):TInterfaceDecl {
		return switch getDecl(packName, name) {
			case TDInterface(iface): iface;
			case _: throw '$packName::$name is not an interface';
		}
	}

	public function getOrCreatePackage(packName:PackageName):TPackage {
		return switch packages[packName] {
			case null: packages[packName] = new TPackage();
			case pack: pack;
		};
	}

	public static function declToType(decl:TDecl):TType {
		return switch decl {
			case TDClass(c): TTInst(IClass(c));
			case TDInterface(i): TTInst(IInterface(i));
			case _: throw "assert";
		}
	}

	public function resolve() {
		for (packName => pack in packages) {
			for (modName => mod in pack.asMap()) {
				function resolvePath(packName:String, name:String):TType {
					if (packName != "") {
						// already full path
						return declToType(getDecl(packName, name));
					}

					if (mod.name == name) {
						return declToType(mod.pack.decl);
					}

					var modInPack = pack.getModule(name);
					if (modInPack != null) {
						return declToType(modInPack.pack.decl);
					}

					var toplevel = packages[""].getModule(name);
					if (toplevel != null) {
						return declToType(toplevel.pack.decl);
					}

					throw 'Unknown $packName::$name';
				}

				function resolveType(t:TType):TType {
					return switch t {
						case TTVoid
						   | TTAny
						   | TTBoolean
						   | TTNumber
						   | TTInt
						   | TTUint
						   | TTString
						   | TTFunction
						   | TTClass
						   | TTXML
						   | TTXMLList
						   | TTRegExp
						   | TTBuiltin
						   | TTInst(_)
						   | TTStatic(_)
						   : t;
						case TTArray(t):
							TTArray(resolveType(t));
						case TTVector(t):
							TTVector(resolveType(t));
						case TTObject(t):
							TTObject(resolveType(t));
						case TTDictionary(k, v):
							TTDictionary(resolveType(k), resolveType(v));
						case TTFun(args, ret, rest):
							TTFun([for (t in args) resolveType(t)], resolveType(ret), rest);
					}
				}

				function resolveSig(sig:TFunctionSignature) {
					for (arg in sig.args) {
						arg.type = resolveType(arg.type);
					}
					sig.ret.type = resolveType(sig.ret.type);
				}

				function resolveVars(vars:Array<TVarFieldDecl>) {
					for (v in vars) {
						v.type = resolveType(v.type);
					}
				}

				function resolveDecl(d:TDecl) {
					switch (d) {
						case TDNamespace(_):
							// nothing to resolve :)

						case TDClass(c):
							for (m in c.members) {
								switch m {
									case TMField({kind: TFFun({fun: f}) | TFGetter({fun: f}) | TFSetter({fun: f})}):
										resolveSig(f.sig);
									case TMField({kind: TFVar(v)}):
										resolveVars(v.vars);
									case TMCondCompBegin(_) | TMCondCompEnd(_) | TMUseNamespace(_, _) | TMStaticInit(_):
								}
							}

						case TDInterface(c):
							for (m in c.members) {
								switch m {
									case TIMField({kind: TIFFun({sig: sig}) | TIFGetter({sig: sig}) | TIFSetter({sig: sig})}):
										resolveSig(sig);
									case TIMCondCompBegin(_) | TIMCondCompEnd(_):
								}
							}

						case TDVar(v):
							resolveVars(v.vars);

						case TDFunction(f):
							resolveSig(f.fun.sig);
					}
				}

				resolveDecl(mod.pack.decl);
			}
		}
	}

	public function dump() {
		return [for (name => pack in packages) pack.dump(name)].join("\n\n\n");
	}
}

abstract TPackage(Map<ModuleName,TModule>) {
	public inline function new() {
		this = new Map();
	}

	public inline function asMap() return this;

	public inline function getModule(moduleName:ModuleName):Null<TModule> {
		return this[moduleName];
	}

	public inline function addModule(module:TModule) {
		if (this.exists(module.name)) throw 'Module ${module.name} is already defined!';
		this[module.name] = module;
	}

	public function dump(name:String) {
		return (if (name == "") "<root>" else name) + "\n" + [for (name => module in this) dumpModule(name, module)].join("\n\n");
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
		switch (d) {
			case TDVar(v):
				return [for (v in v.vars) indent + dumpVar("VAR", v.name, v.type)].join("\n");
			case TDFunction(f):
				return indent + dumpFun(f.name, f.fun.sig);
			case TDNamespace({name: {text: name}}):
				return indent + "NS " + name;
			case TDInterface(i):
				var r = [indent + "IFACE " + i.name];
				if (i.extend != null) {
					r.push(indent + " - EXT: " + [for (i in i.extend.interfaces) i.iface.decl.name].join(", "));
				}
				for (m in i.members) {
					switch (m) {
						case TIMField(f): r.push(dumpInterfaceField(f));
						case TIMCondCompBegin(_) | TIMCondCompEnd(_):
					}
				}
				return r.join("\n");
			case TDClass(c):
				var r = [indent + "CLS " + c.name];
				if (c.extend != null) {
					r.push(indent + " - EXT: " + c.extend.superClass.name);
				}
				for (m in c.members) {
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

	static function dumpInterfaceField(f:TInterfaceField):String {
		var prefix = indent + indent + indent + indent;
		return prefix + switch (f.kind) {
			case TIFFun(f): dumpFun(f.name, f.sig);
			case TIFGetter(f): dumpVar("GET", f.name, f.sig.ret.type);
			case TIFSetter(f): dumpVar("SET", f.name, f.sig.args[0].type);
		}
	}

	static function dumpClassField(f:TClassField):String {
		var prefix = indent + indent + indent + indent;
		return switch (f.kind) {
			case TFFun(f): prefix + dumpFun(f.name, f.fun.sig);
			case TFVar(f): [for (v in f.vars) prefix + dumpVar("VAR", v.name, v.type) ].join("\n");
			case TFGetter(f): prefix + dumpVar("GET", f.name, f.fun.sig.ret.type);
			case TFSetter(f): prefix + dumpVar("SET", f.name, f.fun.sig.args[0].type);
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
			case TTInst(IClass({name: name}) | IInterface({name: name})): name;
			case TTStatic(c): c.name;
			case TTBuiltin: "BUILTIN";
		}
	}
}

typedef TModule = {
	var path:String;
	var pack:TPackageDecl;
	var name:String;
	var privateDecls:Array<TDecl>;
	var eof:Token;
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
	var pack:SPackage;
	var kind:TImportKind;
}

enum TImportKind {
	TIDecl(d:SDecl);
	TIAliased(d:SDecl, as:Token, name:Token);
	TIAll(dot:Token, asterisk:Token);
}

typedef TCondCompBegin = {
	var v:TCondCompVar;
	var openBrace:Token;
}

typedef TCondCompEnd = {closeBrace:Token}

enum TDecl {
	TDClass(c:TClassDecl);
	TDInterface(c:TInterfaceDecl);
	TDVar(v:TModuleVarDecl);
	TDFunction(v:TFunctionDecl);
	TDNamespace(n:NamespaceDecl);
}

typedef TFunctionDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var syntax:{keyword:Token, name:Token};
	var name:String;
	var fun:TFunction;
}

typedef TModuleVarDecl = TVarField & {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
}

typedef TInterfaceDecl = {
	var syntax:{
		var keyword:Token;
		var name:Token;
		var openBrace:Token;
		var closeBrace:Token;
	};
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var name:String;
	var extend:Null<TClassImplement>;
	var members:Array<TInterfaceMember>;
}

typedef TClassDecl = {
	var syntax:{
		var keyword:Token;
		var name:Token;
		var implement:Null<{keyword:Token, paths:Separated<DotPath>}>;
		var openBrace:Token;
		var closeBrace:Token;
	};
	var properties:Null<Map<String,THaxePropDecl>>;
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var name:String;
	var structure:SClassDecl;
	var extend:Null<TClassExtend>;
	var implement:Null<TClassImplement>;
	var members:Array<TClassMember>;
}

enum TInterfaceMember {
	TIMField(f:TInterfaceField);
	TIMCondCompBegin(b:TCondCompBegin);
	TIMCondCompEnd(b:TCondCompEnd);
}

typedef TInterfaceField = {
	var metadata:Array<Metadata>;
	var kind:TInterfaceFieldKind;
	var semicolon:Token;
}

enum TInterfaceFieldKind {
	TIFFun(f:TIFunctionField);
	TIFGetter(f:TIAccessorField);
	TIFSetter(f:TIAccessorField);
}

typedef TIFunctionField = {
	var syntax:{
		var keyword:Token;
		var name:Token;
	};
	var name:String;
	var sig:TFunctionSignature;
}

typedef TIAccessorField = {
	var syntax:{
		var functionKeyword:Token;
		var accessorKeyword:Token;
		var name:Token;
	}
	var name:String;
	var sig:TFunctionSignature;
}

typedef TClassExtend = {
	var superClass:TClassDecl;
	var syntax:{
		var keyword:Token;
		var path:DotPath;
	};
}

typedef TClassImplement = {
	var syntax:{keyword:Token};
	var interfaces:Array<{iface:TInterfaceHeritage, comma:Null<Token>}>;
}

typedef TInterfaceHeritage = {
	var syntax:DotPath;
	var decl:TInterfaceDecl;
}

enum TClassMember {
	TMUseNamespace(n:UseNamespace, semicolon:Token);
	TMCondCompBegin(b:TCondCompBegin);
	TMCondCompEnd(b:TCondCompEnd);
	TMField(f:TClassField);
	TMStaticInit(i:{expr:TExpr});
}

typedef TClassField = {
	var metadata:Array<Metadata>;
	var namespace:Null<Token>;
	var modifiers:Array<ClassFieldModifier>;
	var kind:TClassFieldKind;
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
	var isPublic:Bool;
	var isStatic:Bool;
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
}

typedef TAccessorField = {
	var syntax:{
		var functionKeyword:Token;
		var accessorKeyword:Token;
		var name:Token;
	}
	var name:String;
	var fun:TFunction;
}

typedef TVarField = {
	var kind:VarDeclKind;
	var isInline:Bool;
	var vars:Array<TVarFieldDecl>;
	var semicolon:Token;
}

typedef TVarFieldDecl = {
	var syntax:{
		var name:Token;
		var type:Null<TypeHint>;
	}
	var name:String;
	var type:TType;
	var init:Null<TVarInit>;
	var comma:Null<Token>;
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
	TEDeclRef(path:DotPath, c:SDecl);
	TECall(eobj:TExpr, args:TCallArgs);
	TECast(c:TCast);
	TEArrayDecl(a:TArrayDecl);
	TEVectorDecl(v:TVectorDecl);
	TEReturn(keyword:Token, e:Null<TExpr>);
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
	TENew(keyword:Token, eclass:TExpr, args:Null<TCallArgs>);
	TECondCompValue(v:TCondCompVar);
	TECondCompBlock(v:TCondCompVar, expr:TExpr);
	TEXmlChild(x:TXmlChild);
	TEXmlAttr(x:TXmlAttr);
	TEXmlAttrExpr(x:TXmlAttrExpr);
	TEXmlDescend(x:TXmlDescend);
	TEUseNamespace(ns:UseNamespace);
	TEHaxeRetype(e:TExpr);
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
	var eelse:Null<{keyword:Token, expr:TExpr}>;
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
	TOImplicitThis(c:SClassDecl);
	TOImplicitClass(c:SClassDecl);
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
	TArgRest(dots:Token);
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
	var syntax:{name:Token, colon:Token, comma:Null<Token>};
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
	TTInst(i:TTInstKind); // class instance access (`obj` in `obj.some`)
	TTStatic(cls:TClassDecl); // class statics access (`Cls` in `Cls.some`)
}

enum TTInstKind {
	IClass(cls:TClassDecl);
	IInterface(cls:TInterfaceDecl);
}

enum TRestKind {
	TRestSwc;
	TRestAs3;
}
