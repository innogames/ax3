package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;
import ax3.Structure;
import ax3.TypedTree;
import ax3.TypedTreeTools.mk;
import ax3.TypedTreeTools.skipParens;

typedef Locals = Map<String, TVar>;

typedef ErrorReporter = (path:String,pos:Int,error:String)->Void;

@:nullSafety
class Typer {
	final structure:Structure;
	final reportError:ErrorReporter;

	@:nullSafety(Off) var locals:Locals;
	@:nullSafety(Off) var localsStack:Array<Locals>;

	@:nullSafety(Off) var currentModule:SModule;
	@:nullSafety(Off) var currentReturnType:TType;

	var currentClass:Null<SClassDecl>;
	var currentPath:String = "<unknown>";

	public function new(structure, reportError) {
		this.structure = structure;
		this.reportError = reportError;
	}

	public inline function err(msg, pos) reportError(currentPath, pos, msg);

	function initLocals() {
		locals = new Map();
		localsStack = [locals];
	}

	function pushLocals() {
		locals = locals.copy();
		localsStack.push(locals);
	}

	function popLocals() {
		localsStack.pop();
		locals = localsStack[localsStack.length - 1];
	}

	function addLocal(name:String, type:TType):TVar {
		return locals[name] = {name: name, type: type};
	}

	public function process(files:Array<File>):Array<TModule> {
		var modules = new Array<TModule>();

		for (file in files) {
			currentPath = file.path;

			var pack = getPackageDecl(file);

			var mainDecl = getPackageMainDecl(pack);

			var privateDecls = getPrivateDecls(file);

			var imports = typeImports(file);

			var namespaceUses = getNamespaceUses(pack);

			var packName = if (pack.name == null) "" else dotPathToString(pack.name);
			var currentPackage = structure.packages[packName];
			if (currentPackage == null) throw "assert";

			var mod = currentPackage.getModule(file.name);
			if (mod == null) throw "assert";
			currentModule = mod;

			var decl = typeDecl(mainDecl);
			var tPrivateDecls = [for (d in privateDecls) typeDecl(d)];

			@:nullSafety(Off) currentModule = null;

			modules.push({
				path: file.path,
				name: file.name,
				pack: {
					syntax: pack,
					name: packName,
					imports: imports,
					namespaceUses: namespaceUses,
					decl: decl,
				},
				privateDecls: tPrivateDecls,
				eof: file.eof
			});

		}

		return modules;
	}

	function typeDecl(d:Declaration):TDecl {
		return switch (d) {
			case DPackage(_) | DImport(_) | DUseNamespace(_): throw "assert";
			case DClass(c):
				TDClass(typeClass(c));
			case DInterface(i):
				TDInterface(typeInterface(i));
			case DFunction(f):
				TDFunction(typeModuleFunction(f));
			case DVar(v):
				TDVar(typeModuleVars(v));
			case DNamespace(ns):
				TDNamespace(ns);
			case DCondComp(v, openBrace, decls, closeBrace): throw "TODO";
		}
	}

	function typeModuleFunction(v:FunctionDecl):TFunctionDecl {
		return {
			metadata: v.metadata,
			modifiers: v.modifiers,
			syntax: {keyword: v.keyword, name: v.name},
			name: v.name.text,
			fun: typeFunction(v.fun)
		};
	}

	function typeModuleVars(v:ModuleVarDecl):TModuleVarDecl {
		return {
			metadata: v.metadata,
			modifiers: v.modifiers,
			kind: v.kind,
			vars: typeVarFieldDecls(v.vars),
			semicolon: v.semicolon
		}
	}

	function typeImports(file:File):Array<TImport> {
		var result = [];
		function loop(decls:Array<Declaration>, condCompBegin:Null<TCondCompBegin>, condCompEnd:Null<TCondCompEnd>) {
			var len = decls.length;
			for (i in 0...len) {
				switch (decls[i]) {
					case DPackage(p): loop(p.declarations, null, null);
					case DImport(imp):
						var condCompBegin = if (i == 0) condCompBegin else null;
						var condCompEnd = if (i == len - 1) condCompEnd else null;
						result.push({
							syntax: imp,
							condCompBegin: condCompBegin,
							condCompEnd: condCompEnd
						});
					case DCondComp(v, openBrace, decls, closeBrace): loop(decls, {v: typeCondCompVar(v), openBrace: openBrace}, {closeBrace: closeBrace});
					case _:
				}
			}
		}
		loop(file.declarations, null, null);
		return result;
	}

	function getNamespaceUses(pack:PackageDecl):Array<{n:UseNamespace, semicolon:Token}> {
		var r = [];
		for (d in pack.declarations) {
			switch d {
				case DUseNamespace(n, semicolon):
					r.push({n: n, semicolon: semicolon});
				case _:
			}
		}
		return r;
	}

	function typeType(t:SType):TType {
		return switch (t) {
			case STVoid: TTVoid;
			case STAny: TTAny;
			case STBoolean: TTBoolean;
			case STNumber: TTNumber;
			case STInt: TTInt;
			case STUint: TTUint;
			case STString: TTString;
			case STArray: TTArray;
			case STFunction: TTFunction;
			case STClass: TTClass;
			case STObject: TTObject;
			case STXML: TTXML;
			case STXMLList: TTXMLList;
			case STRegExp: TTRegExp;
			case STVector(t): TTVector(typeType(t));
			case STPath(path): TTInst(structure.getClass(path));
			case STPrivate(mod, name): TTInst(structure.getPrivateClass(mod, name));
			case STUnresolved(path):  throw "Unresolved type " + path;
		}
	}

	function resolveType(t:SyntaxType):TType {
		return typeType(StructureBuilder.buildTypeStructure(t, currentModule));
	}

	function typeInterface(i:InterfaceDecl):TInterfaceDecl {
		var extend:Null<TClassImplement> =
			if (i.extend == null) null
			else {
				syntax: {keyword: i.extend.keyword},
				interfaces: separatedToArray(i.extend.paths, (path, comma) -> {syntax: path, comma: comma})
			};

		var tMembers = [];
		function loop(members:Array<InterfaceMember>) {
			for (m in members) {
				switch (m) {
					case MICondComp(v, openBrace, members, closeBrace):
						tMembers.push(TIMCondCompBegin({v: typeCondCompVar(v), openBrace: openBrace}));
						loop(members);
						tMembers.push(TIMCondCompEnd({closeBrace: closeBrace}));
					case MIField(f):
						tMembers.push(TIMField(typeInterfaceField(f)));
				}
			}
		}
		loop(i.members);

		return {
			syntax: {
				keyword: i.keyword,
				name: i.name,
				openBrace: i.openBrace,
				closeBrace: i.closeBrace,
			},
			name: i.name.text,
			extend: extend,
			metadata: i.metadata,
			modifiers: i.modifiers,
			members: tMembers,
		}
	}

	function typeInterfaceField(f:InterfaceField):TInterfaceField {
		var kind = switch (f.kind) {
			case IFFun(keyword, name, sig):
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				var sig = typeFunctionSignature(sig, false);
				TIFFun({
					syntax: {
						keyword: keyword,
						name: name,
					},
					name: name.text,
					sig: sig
				});
			case IFGetter(keyword, get, name, sig):
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				var sig = typeFunctionSignature(sig, false);
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
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				var sig = typeFunctionSignature(sig, false);
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

	function typeClass(c:ClassDecl):TClassDecl {
		switch currentModule.getDecl(c.name.text) {
			case null: throw "assert"; // no way
			case {kind: SClass(cls)}: currentClass = cls;
			case _:
		}

		var extend:Null<TClassExtend> =
			if (c.extend == null) null
			else {syntax: c.extend};

		var implement:Null<TClassImplement> =
			if (c.implement == null) null
			else {
				syntax: {keyword: c.implement.keyword},
				interfaces: separatedToArray(c.implement.paths, (path, comma) -> {syntax: path, comma: comma})
			};

		var tMembers = [];
		function loop(members:Array<ClassMember>) {
			for (m in members) {
				switch (m) {
					case MCondComp(v, openBrace, members, closeBrace):
						tMembers.push(TMCondCompBegin({v: typeCondCompVar(v), openBrace: openBrace}));
						loop(members);
						tMembers.push(TMCondCompEnd({closeBrace: closeBrace}));
					case MUseNamespace(n, semicolon):
						tMembers.push(TMUseNamespace(n, semicolon));
					case MField(f):
						tMembers.push(TMField(typeClassField(f)));
					case MStaticInit(block):
						var expr = mk(TEBlock(typeBlock(block)), TTVoid, TTVoid);
						tMembers.push(TMStaticInit({expr: expr}));
				}
			}
		}
		loop(c.members);

		currentClass = null;

		return {
			syntax: c,
			name: c.name.text,
			metadata: c.metadata,
			extend: extend,
			implement: implement,
			modifiers: c.modifiers,
			members: tMembers,
		}
	}

	function typeVarFieldDecls(vars:Separated<VarDecl>):Array<TVarFieldDecl> {
		return separatedToArray(vars, function(v, comma) {
			var type = if (v.type == null) TTAny else resolveType(v.type.type);
			var init = if (v.init != null) typeVarInit(v.init, type) else null;
			return {
				syntax:{
					name: v.name,
					type: v.type
				},
				name: v.name.text,
				type: type,
				init: init,
				comma: comma,
			};
		});
	}

	function typeClassField(f:ClassField):TClassField {
		var kind = switch (f.kind) {
			case FVar(kind, vars, semicolon):
				TFVar({
					kind: kind,
					vars: typeVarFieldDecls(vars),
					semicolon: semicolon
				});
			case FFun(keyword, name, fun):
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				var f = typeFunction(fun);
				TFFun({
					syntax: {
						keyword: keyword,
						name: name,
					},
					name: name.text,
					fun: f
				});
			case FGetter(keyword, get, name, fun):
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				var f = typeFunction(fun);
				TFGetter({
					syntax: {
						functionKeyword: keyword,
						accessorKeyword: get,
						name: name,
					},
					name: name.text,
					fun: f
				});
			case FSetter(keyword, set, name, fun):
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				var f = typeFunction(fun);
				TFSetter({
					syntax: {
						functionKeyword: keyword,
						accessorKeyword: set,
						name: name,
					},
					name: name.text,
					fun: f
				});
		}
		return {
			metadata: f.metadata,
			namespace: f.namespace,
			modifiers: f.modifiers,
			kind: kind
		};
	}

	function typeFunctionSignature(sig:FunctionSignature, addArgLocals:Bool):TFunctionSignature {
		var targs =
			if (sig.args != null) {
				separatedToArray(sig.args, function(arg, comma) {
					return switch (arg) {
						case ArgNormal(a):
							var type = if (a.type == null) TTAny else resolveType(a.type.type);
							var init = if (a.init == null) null else typeVarInit(a.init, type);
							if (addArgLocals) addLocal(a.name.text, type);
							{syntax: {name: a.name}, name: a.name.text, type: type, kind: TArgNormal(a.type, init), comma: comma};
						case ArgRest(dots, name):
							if (addArgLocals) addLocal(name.text, TTArray);
							{syntax: {name: name}, name: name.text, type: TTArray, kind: TArgRest(dots), comma: comma};
					}
				});
			} else {
				[];
			};

		var tret:TTypeHint;
		if (sig.ret != null) {
			tret = {
				type: resolveType(sig.ret.type),
				syntax: sig.ret
			};
		} else {
			tret = {type: TTAny, syntax: null};
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

	function typeFunction(fun:Function):TFunction {
		pushLocals();

		var sig = typeFunctionSignature(fun.signature, true);

		var oldReturnType = currentReturnType;
		currentReturnType = sig.ret.type;

		var block = typeBlock(fun.block);

		currentReturnType = oldReturnType;

		popLocals();

		return {
			sig: sig,
			expr: mk(TEBlock(block), TTVoid, TTVoid)
		};
	}

	function typeExpr(e:Expr, expectedType:TType):TExpr {
		return switch (e) {
			case EIdent(i):
				typeIdent(i, e, expectedType);

			case ELiteral(l):
				typeLiteral(l, expectedType);

			case ECall(e, args):
				typeCall(e, args, expectedType);

			case EParens(openParen, e, closeParen):
				var e = typeExpr(e, expectedType);
				mk(TEParens(openParen, e, closeParen), e.type, expectedType);

			case EArrayAccess(e, openBracket, eindex, closeBracket):
				typeArrayAccess(e, openBracket, eindex, closeBracket, expectedType);

			case EArrayDecl(d):
				typeArrayDecl(d, expectedType);

			case EVectorDecl(newKeyword, t, d):
				typeVectorDecl(newKeyword, t, d, expectedType);

			case EReturn(keyword, eReturned):
				if (expectedType != TTVoid) throw "assert";
				mk(TEReturn(keyword, if (eReturned != null) typeExpr(eReturned, currentReturnType) else null), TTVoid, TTVoid);

			case EThrow(keyword, e):
				if (expectedType != TTVoid) throw "assert";
				mk(TEThrow(keyword, typeExpr(e, TTAny)), TTVoid, TTVoid);

			case EBreak(keyword):
				if (expectedType != TTVoid) throw "assert";
				mk(TEBreak(keyword), TTVoid, TTVoid);

			case EContinue(keyword):
				if (expectedType != TTVoid) throw "assert";
				mk(TEContinue(keyword), TTVoid, TTVoid);

			case EDelete(keyword, e):
				mk(TEDelete(keyword, typeExpr(e, TTAny)), TTBoolean, expectedType);

			case ENew(keyword, e, args): typeNew(keyword, e, args, expectedType);
			case EField(eobj, dot, fieldName): typeField(eobj, dot, fieldName, expectedType);
			case EBlock(b): mk(TEBlock(typeBlock(b)), TTVoid, TTVoid);
			case EObjectDecl(openBrace, fields, closeBrace): typeObjectDecl(openBrace, fields, closeBrace, expectedType);
			case EIf(keyword, openParen, econd, closeParen, ethen, eelse): typeIf(keyword, openParen, econd, closeParen, ethen, eelse, expectedType);
			case ETernary(econd, question, ethen, colon, eelse): typeTernary(econd, question, ethen, colon, eelse, expectedType);
			case EWhile(w): typeWhile(w, expectedType);
			case EDoWhile(w): typeDoWhile(w, expectedType);
			case EFor(f): typeFor(f, expectedType);
			case EForIn(f): typeForIn(f, expectedType);
			case EForEach(f): typeForEach(f, expectedType);
			case EBinop(a, op, b): typeBinop(a, op, b, expectedType);
			case EPreUnop(op, e): typePreUnop(op, e, expectedType);
			case EPostUnop(e, op): typePostUnop(e, op, expectedType);
			case EVars(kind, vars): typeVars(kind, vars, expectedType);
			case EAs(e, keyword, t): typeAs(e, keyword, t, expectedType);
			case EIs(e, keyword, et): typeIs(e, keyword, et, expectedType);
			case EVector(v): typeVector(v, expectedType);
			case ESwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace): typeSwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace, expectedType);
			case ETry(keyword, block, catches, finally_): typeTry(keyword, block, catches, finally_, expectedType);
			case EFunction(keyword, name, fun): typeLocalFunction(keyword, name, fun, expectedType);

			case EXmlAttr(e, dot, at, attrName): typeXmlAttr(e, dot, at, attrName, expectedType);
			case EXmlAttrExpr(e, dot, at, openBracket, eattr, closeBracket): typeXmlAttrExpr(e, dot, at, openBracket, eattr, closeBracket, expectedType);
			case EXmlDescend(e, dotDot, childName): typeXmlDescend(e, dotDot, childName, expectedType);
			case ECondCompValue(v): mk(TECondCompValue(typeCondCompVar(v)), TTAny, expectedType);
			case ECondCompBlock(v, b): typeCondCompBlock(v, b, expectedType);
			case EUseNamespace(ns): mk(TEUseNamespace(ns), TTVoid, expectedType);
		}
	}

	function typeLocalFunction(keyword:Token, name:Null<Token>, fun:Function, expectedType:TType):TExpr {
		return mk(TELocalFunction({
			syntax: {keyword: keyword},
			name: if (name == null) null else {name: name.text, syntax: name},
			fun: typeFunction(fun),
		}), TTFunction, expectedType); // TODO: TTFun, why not?
	}

	function typePreUnop(op:PreUnop, e:Expr, expectedType:TType):TExpr {
		var inType, outType;
		switch (op) {
			case PreNot(_): inType = outType = TTBoolean;
			case PreNeg(_): inType = outType = TTNumber;
			case PreIncr(_): inType = outType = TTNumber;
			case PreDecr(_): inType = outType = TTNumber;
			case PreBitNeg(_): inType = TTNumber; outType = TTInt;
		}
		var e = typeExpr(e, inType);
		return mk(TEPreUnop(op, e), outType, expectedType);
	}

	function typePostUnop(e:Expr, op:PostUnop, expectedType:TType):TExpr {
		var e = typeExpr(e, TTNumber);
		var type = switch (op) {
			case PostIncr(_): e.type;
			case PostDecr(_): e.type;
		}
		return mk(TEPostUnop(e, op), type, expectedType);
	}

	function typeXmlAttr(e:Expr, dot:Token, at:Token, attrName:Token, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		return mk(TEXmlAttr({
			syntax: {
				dot: dot,
				at: at,
				name: attrName
			},
			eobj: e,
			name: attrName.text
		}), TTXMLList, expectedType);
	}

	function typeXmlAttrExpr(e:Expr, dot:Token, at:Token, openBracket:Token, eattr:Expr, closeBracket:Token, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		var eattr = typeExpr(eattr, TTString);
		return mk(TEXmlAttrExpr({
			syntax: {
				dot: dot,
				at: at,
				openBracket: openBracket,
				closeBracket: closeBracket
			},
			eobj: e,
			eattr: eattr,
		}), TTXMLList, expectedType);
	}

	function typeXmlDescend(e:Expr, dotDot:Token, childName:Token, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		return mk(TEXmlDescend({
			syntax: {dotDot: dotDot, name: childName},
			eobj: e,
			name: childName.text
		}), TTXMLList, expectedType);
	}

	function typeCondCompVar(v:CondCompVar):TCondCompVar {
		return {syntax: v, ns: v.ns.text, name: v.name.text};
	}

	function typeCondCompBlock(v:CondCompVar, block:BracedExprBlock, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var expr = typeExpr(EBlock(block), TTVoid);
		return mk(TECondCompBlock(typeCondCompVar(v), expr), TTVoid, TTVoid);
	}

	function typeVector(v:VectorSyntax, expectedType:TType):TExpr {
		var type = resolveType(v.t.type);
		return mk(TEVector(v, type), TTFun([TTObject], TTVector(type)), expectedType);
	}

	function typeTry(keyword:Token, block:BracedExprBlock, catches:Array<Catch>, finally_:Null<Finally>, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		if (finally_ != null) throw "finally is unsupported";
		var body = typeExpr(EBlock(block), TTVoid);
		var tCatches = new Array<TCatch>();
		for (c in catches) {
			pushLocals();
			var v = addLocal(c.name.text, resolveType(c.type.type));
			var e = typeExpr(EBlock(c.block), TTVoid);
			popLocals();
			tCatches.push({
				syntax: {
					keyword: c.keyword,
					openParen: c.openParen,
					name: c.name,
					type: c.type,
					closeParen: c.closeParen
				},
				v: v,
				expr: e
			});
		}
		return mk(TETry({
			keyword: keyword,
			expr: body,
			catches: tCatches
		}), TTVoid, TTVoid);
	}

	function typeSwitch(keyword:Token, openParen:Token, subj:Expr, closeParen:Token, openBrace:Token, cases:Array<SwitchCase>, closeBrace:Token, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var subj = typeExpr(subj, TTAny);
		var tcases = new Array<TSwitchCase>();
		var def:Null<TSwitchDefault> = null;
		for (c in cases) {
			switch (c) {
				case CCase(keyword, v, colon, body):
					if (def != null) throw "`case` after `default` in switch";
					tcases.push({
						syntax: {
							keyword: keyword,
							colon: colon,
						},
						value: typeExpr(v, TTAny),
						body: [for (e in body) {expr: typeExpr(e.expr, TTVoid), semicolon: e.semicolon}]
					});
				case CDefault(keyword, colon, body):
					if (def != null) throw "double `default` in switch";
					def = {
						syntax: {
							keyword: keyword,
							colon: colon,
						},
						body: [for (e in body) {expr: typeExpr(e.expr, TTVoid), semicolon: e.semicolon}]
					};
			}
		}
		return mk(TESwitch({
			syntax: {
				keyword: keyword,
				openParen: openParen,
				closeParen: closeParen,
				openBrace: openBrace,
				closeBrace: closeBrace
			},
			subj: subj,
			cases: tcases,
			def: def
		}), TTVoid, TTVoid);
	}

	function typeAs(e:Expr, keyword:Token, t:SyntaxType, expectedType:TType) {
		var e = typeExpr(e, TTAny);
		var type = resolveType(t);
		return mk(TEAs(e, keyword, {syntax: t, type: type}), type, expectedType);
	}

	function typeIs(e:Expr, keyword:Token, etype:Expr, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		var etype = typeExpr(etype, TTAny);
		return mk(TEIs(e, keyword, etype), TTBoolean, expectedType);
	}

	function typeBinop(a:Expr, op:Binop, b:Expr, expectedType:TType):TExpr {
		var a = typeExpr(a, TTAny);
		var b = typeExpr(b, TTAny);
		var type = switch (op) { // TODO: this can be more accurate
			case OpEquals(_) | OpNotEquals(_) | OpStrictEquals(_) | OpNotStrictEquals(_): TTBoolean;
			case OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_) | OpIn(_): TTBoolean;
			case OpAdd(_) | OpSub(_) | OpDiv(_) | OpMul(_) | OpMod(_): a.type;
			case OpAssignAdd(_) | OpAssignSub(_) | OpAssignMul(_) | OpAssignDiv(_) | OpAssignMod(_): a.type;
			case OpAssignBitAnd(_) | OpAssignBitOr(_) | OpAssignBitXor(_): a.type;
			case OpAssignShl(_) | OpAssignShr(_) | OpAssignUshr(_) | OpAssign(_): a.type;
			case OpAssignAnd(_) | OpAssignOr(_): a.type;
			case OpAnd(_) | OpOr(_) | OpShl(_) | OpShr(_) | OpUshr(_): a.type;
			case OpBitAnd(_) | OpBitOr(_) | OpBitXor(_): a.type;
			case OpComma(_): b.type;
		}
		return mk(TEBinop(a, op, b), type, expectedType);
	}

	function typeForIn(f:ForIn, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		pushLocals();
		var eobj = typeExpr(f.iter.eobj, TTAny);
		var eit = typeExpr(f.iter.eit, TTAny);
		var ebody = typeExpr(f.body, TTVoid);
		popLocals();
		return mk(TEForIn({
			syntax: {
				forKeyword: f.forKeyword,
				openParen: f.openParen,
				closeParen: f.closeParen
			},
			iter: {
				eit: eit,
				inKeyword: f.iter.inKeyword,
				eobj: eobj
			},
			body: ebody
		}), TTVoid, TTVoid);
	}

	function typeForEach(f:ForEach, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		pushLocals();
		var eobj = typeExpr(f.iter.eobj, TTAny);
		var eit = typeExpr(f.iter.eit, TTAny);
		var ebody = typeExpr(f.body, TTVoid);
		popLocals();
		return mk(TEForEach({
			syntax: {
				forKeyword: f.forKeyword,
				eachKeyword: f.eachKeyword,
				openParen: f.openParen,
				closeParen: f.closeParen
			},
			iter: {
				eit: eit,
				inKeyword: f.iter.inKeyword,
				eobj: eobj
			},
			body: ebody
		}), TTVoid, TTVoid);
	}

	function typeFor(f:For, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		pushLocals();
		var einit = if (f.einit != null) typeExpr(f.einit, TTVoid) else null;
		var econd = if (f.econd != null) typeExpr(f.econd, TTBoolean) else null;
		var eincr = if (f.eincr != null) typeExpr(f.eincr, TTVoid) else null;
		var ebody = typeExpr(f.body, TTVoid);
		popLocals();
		return mk(TEFor({
			syntax: {
				keyword: f.keyword,
				openParen: f.openParen,
				initSep: f.initSep,
				condSep: f.condSep,
				closeParen: f.closeParen
			},
			einit: einit,
			econd: econd,
			eincr: eincr,
			body: ebody
		}), TTVoid, TTVoid);
	}

	function typeWhile(w:While, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var econd = typeExpr(w.cond, TTBoolean);
		var ebody = typeExpr(w.body, TTVoid);
		return mk(TEWhile({
			syntax: {keyword: w.keyword, openParen: w.openParen, closeParen: w.closeParen},
			cond: econd,
			body: ebody
		}), TTVoid, TTVoid);
	}

	function typeDoWhile(w:DoWhile, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var ebody = typeExpr(w.body, TTVoid);
		var econd = typeExpr(w.cond, TTBoolean);
		return mk(TEDoWhile({
			syntax: {doKeyword: w.doKeyword, whileKeyword: w.whileKeyword, openParen: w.openParen, closeParen: w.closeParen},
			body: ebody,
			cond: econd
		}), TTVoid, TTVoid);
	}

	function typeIf(keyword:Token, openParen:Token, econd:Expr, closeParen:Token, ethen:Expr, eelse:Null<{keyword:Token, expr:Expr}>, expectedType:TType):TExpr {
		if (expectedType != TTVoid) throw "assert";

		var econd = typeExpr(econd, TTBoolean);
		var ethen = typeExpr(ethen, TTVoid);
		var eelse = if (eelse != null) {keyword: eelse.keyword, expr: typeExpr(eelse.expr, TTVoid)} else null;
		return mk(TEIf({
			syntax: {keyword: keyword, openParen: openParen, closeParen: closeParen},
			econd: econd,
			ethen: ethen,
			eelse: eelse
		}), TTVoid, TTVoid);
	}

	function typeTernary(econd:Expr, question:Token, ethen:Expr, colon:Token, eelse:Expr, expectedType:TType):TExpr {
		var econd = typeExpr(econd, TTBoolean);
		var ethen = typeExpr(ethen, expectedType);
		var eelse = typeExpr(eelse, expectedType);
		return mk(TETernary({
			syntax: {question: question, colon: colon},
			econd: econd,
			ethen: ethen,
			eelse: eelse
		}), ethen.type, expectedType);
	}

	function typeCallArgs(args:CallArgs, callableType:TType):TCallArgs {
		var getExpectedType = switch (callableType) {
			case TTVoid | TTBoolean | TTNumber | TTInt | TTUint | TTString | TTArray | TTObject | TTXML | TTXMLList | TTRegExp | TTVector(_) | TTInst(_):
				throw "assert";
			case TTClass:
				throw "assert??";
			case TTAny | TTFunction:
				(i,earg) -> TTAny;
			case TTBuiltin | TTStatic(_):
				(i,earg) -> TTAny; // TODO: casts should be handled elsewhere
			case TTFun(args, _, rest):
				function(i:Int, earg:Expr):TType {
					if (i >= args.length) {
						if (rest == null) {
							err("Invalid number of arguments", exprPos(earg));
						}
						return TTAny;
					} else {
						return args[i];
					}
				}
		}

		return {
			openParen: args.openParen,
			closeParen: args.closeParen,
			args:
				if (args.args != null) {
					var i = 0;
					separatedToArray(args.args, function(expr, comma) {
						var expectedType = getExpectedType(i, expr);
						i++;
						return {expr: typeExpr(expr, expectedType), comma: comma};
					});
				} else
					[]
		};
	}

	function typeCall(e:Expr, args:CallArgs, expectedType:TType) {
		var eobj = typeExpr(e, TTAny);

		var callableType = switch eobj {
			case {kind: TELiteral(TLSuper(_)), type: TTInst(cls)}: getConstructorType(cls);
			case _: eobj.type;
		}
		var targs = typeCallArgs(args, callableType);

		inline function mkCast(path, t) return {
			var e = switch targs.args {
				case [{expr: e, comma: null}]: e;
				case _: throw "assert"; // should NOT happen
			};
			return mk(TECast({
				syntax: {openParen: args.openParen, closeParen: args.closeParen, path: path},
				type: t,
				expr: e
			}), t, expectedType);
		}

		inline function mkDotPath(ident:Token):DotPath return {first: ident, rest: []};

		var type;
		switch skipParens(eobj) {
			case {kind: TELiteral(TLSuper(_))}: // super(...) call
				type = TTVoid;

			case {type: TTAny}: // bad untyped call :-)
				// err("Untyped call", args.openParen.pos);
				type = TTAny;

			case {type: TTFunction}: // also untyped call, but inevitable
				type = TTAny;

			case {type: TTFun(_, ret)}: // known function type call
				type = ret;

			case {kind: TEBuiltin(syntax, "int")}:
				return mkCast(mkDotPath(syntax), TTInt);

			case {kind: TEBuiltin(syntax, "uint")}:
				return mkCast(mkDotPath(syntax), TTUint);

			case {kind: TEBuiltin(syntax, "Boolean")}:
				return mkCast(mkDotPath(syntax), TTBoolean);

			case {kind: TEBuiltin(syntax, "String")}:
				return mkCast(mkDotPath(syntax), TTString);

			case {kind: TEBuiltin(syntax, "Number")}:
				return mkCast(mkDotPath(syntax), TTNumber);

			case {kind: TEBuiltin(syntax, "XML")}:
				return mkCast(mkDotPath(syntax), TTXML);

			case {kind: TEDeclRef(path, _), type: TTStatic(cls)}: // ClassName(expr) cast
				return mkCast(path, TTInst(cls));

			case _:
				err("unknown callable type: " + eobj.type, exprPos(e));
				type = TTAny;
		}

		return mk(TECall(eobj, targs), type, expectedType);
	}

	function getConstructorType(cls:SClassDecl):TType {
		var ctor = structure.getConstructor(cls);
		return if (ctor != null) getTypeOfFunctionDecl(ctor) else TTFun([], TTVoid, null);
	}

	function typeNew(keyword:Token, e:Expr, args:Null<CallArgs>, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);

		var type, ctorType;
		switch (e.type) {
			case TTStatic(cls):
				ctorType = getConstructorType(cls);
				type = TTInst(cls);
			case _:
				ctorType = TTFunction;
				type = TTObject; // TODO: is this correct?
		};

		var args = if (args != null) typeCallArgs(args, ctorType) else null;
		return mk(TENew(keyword, e, args), type, expectedType);
	}

	function typeBlock(b:BracedExprBlock):TBlock {
		pushLocals();
		var exprs = [];
		for (e in b.exprs) {
			exprs.push({
				expr: typeExpr(e.expr, TTVoid),
				semicolon: e.semicolon
			});
		}
		popLocals();
		return {
			syntax: {openBrace: b.openBrace, closeBrace: b.closeBrace},
			exprs: exprs
		};
	}

	function typeArrayAccess(e:Expr, openBracket:Token, eindex:Expr, closeBracket:Token, expectedType:TType):TExpr {
		var e = typeExpr(e, TTAny);
		var eindex = typeExpr(eindex, TTAny);
		var type = switch (e.type) {
			case TTVector(t):
				t;
			case TTArray:
				switch (eindex.type) {
					case TTNumber | TTInt | TTUint:
					case _:
						// err("Array access with non-numeric index", openBracket.pos);
				}
				TTAny;
			case TTObject | TTInst({name: "Dictionary"}):
				TTAny;
			case _:
				// err("Untyped array access", openBracket.pos);
				TTAny;
		};
		return mk(TEArrayAccess({
			syntax: {openBracket: openBracket, closeBracket: closeBracket},
			eobj: e,
			eindex: eindex
		}), type, expectedType);
	}

	function typeArrayDeclElements(d:ArrayDecl, elemExpectedType:TType) {
		var elems = if (d.elems == null) [] else separatedToArray(d.elems, (e, comma) -> {expr: typeExpr(e, elemExpectedType), comma: comma});
		return {
			syntax: {openBracket: d.openBracket, closeBracket: d.closeBracket},
			elements: elems
		};
	}

	function typeArrayDecl(d:ArrayDecl, expectedType:TType):TExpr {
		return mk(TEArrayDecl(typeArrayDeclElements(d, TTAny)), TTArray, expectedType);
	}

	function typeVectorDecl(newKeyword:Token, t:TypeParam, d:ArrayDecl, expectedType:TType):TExpr {
		var type = resolveType(t.type);
		var elems = typeArrayDeclElements(d, type);
		return mk(TEVectorDecl({
			syntax: {newKeyword: newKeyword, typeParam: t},
			elements: elems,
			type: type
		}), TTVector(type), expectedType);
	}

	function getTypeOfFunctionDecl(f:SFunDecl):TType {
		var args = [], rest:Null<TRestKind> = null;
		for (a in f.args) {
			switch (a.kind) {
				case SArgNormal(_): args.push(typeType(a.type));
				case SArgRest(_): rest = if (f.swc) TRestSwc else TRestAs3;
			}
		}
		return TTFun(args, typeType(f.ret), rest);
	}

	function mkDeclRef(path:DotPath, decl:SDecl, expectedType:TType):TExpr {
		var type = switch (decl.kind) {
			case SVar(v): typeType(v.type);
			case SFun(f): getTypeOfFunctionDecl(f);
			case SClass(c): TTStatic(c);
			case SNamespace: throw "assert"; // should NOT happen :)
		};
		return mk(TEDeclRef(path, decl), type, expectedType);
	}

	function getFieldType(field:SClassField):TType {
		var t = switch (field.kind) {
			case SFVar(v): typeType(v.type);
			case SFFun(f): getTypeOfFunctionDecl(f);
		};
		if (t == TTVoid) throw "assert";
		return t;
	}

	function tryTypeIdent(i:Token, expectedType:TType):Null<TExpr> {
		inline function getCurrentClass(subj) return if (currentClass != null) currentClass else throw '`$subj` used outside of class';

		return switch i.text {
			case "this": mk(TELiteral(TLThis(i)), TTInst(getCurrentClass("this")), expectedType);
			case "super": mk(TELiteral(TLSuper(i)), TTInst(structure.getClass(getCurrentClass("super").extensions[0])), expectedType);
			case "true" | "false": mk(TELiteral(TLBool(i)), TTBoolean, expectedType);
			case "null": mk(TELiteral(TLNull(i)), TTAny, expectedType);
			case "undefined": mk(TELiteral(TLUndefined(i)), TTAny, expectedType);
			case "arguments": mk(TEBuiltin(i, "arguments"), TTBuiltin, expectedType);
			case "trace": mk(TEBuiltin(i, "trace"), TTFun([], TTVoid, TRestSwc), expectedType);
			case "int": mk(TEBuiltin(i, "int"), TTBuiltin, expectedType);
			case "uint": mk(TEBuiltin(i, "int"), TTBuiltin, expectedType);
			case "Boolean": mk(TEBuiltin(i, "Boolean"), TTBuiltin, expectedType);
			case "Number": mk(TEBuiltin(i, "Number"), TTBuiltin, expectedType);
			case "XML": mk(TEBuiltin(i, "XML"), TTBuiltin, expectedType);
			case "XMLList": mk(TEBuiltin(i, "XMLList"), TTBuiltin, expectedType);
			case "String": mk(TEBuiltin(i, "String"), TTBuiltin, expectedType);
			case "Array": mk(TEBuiltin(i, "Array"), TTBuiltin, expectedType);
			case "Function": mk(TEBuiltin(i, "Function"), TTBuiltin, expectedType);
			case "Class": mk(TEBuiltin(i, "Class"), TTBuiltin, expectedType);
			case "Object": mk(TEBuiltin(i, "Object"), TTBuiltin, expectedType);
			case "RegExp": mk(TEBuiltin(i, "RegExp"), TTBuiltin, expectedType);
			// TODO: actually these must be resolved after everything because they are global idents!!!
			case "parseInt":  mk(TEBuiltin(i, "parseInt"), TTFun([TTString], TTInt), expectedType);
			case "parseFloat": mk(TEBuiltin(i, "parseFloat"), TTFun([TTString], TTNumber), expectedType);
			case "NaN": mk(TEBuiltin(i, "NaN"), TTNumber, expectedType);
			case "isNaN": mk(TEBuiltin(i, "isNaN"), TTFun([TTNumber], TTBoolean), expectedType);
			case "escape": mk(TEBuiltin(i, "escape"), TTFun([TTString], TTString), expectedType);
			case "unescape": mk(TEBuiltin(i, "unescape"), TTFun([TTString], TTString), expectedType);
			case ident:
				var v = locals[ident];
				if (v != null) {
					return mk(TELocal(i, v), v.type, expectedType);
				}

				if (currentClass != null) {
					var currentClass:SClassDecl = currentClass; // TODO: this is here only to please the null-safety checker
					function loop(c:SClassDecl):Null<TExpr> {
						if (ident == c.name) {
							// class constructor is never resolved like that, so this is definitely a declaration reference
							return mkDeclRef({first: i, rest: []}, {name: ident, kind: SClass(c)}, expectedType);
						}

						var field = c.fields.get(ident);
						if (field != null) {
							// found a field
							var eobj = {
								kind: TOImplicitThis(currentClass),
								type: TTInst(currentClass)
							};
							var type = getFieldType(field);
							return mk(TEField(eobj, ident, i), type, expectedType);
						}
						for (ext in c.extensions) {
							var e = loop(structure.getClass(ext));
							if (e != null) {
								return e;
							}
						}
						return null;
					}
					var eField = loop(currentClass);
					if (eField != null) {
						return eField;
					}

					// TODO: copypasta

					function loop(c:SClassDecl):Null<TExpr> {
						var field = c.statics.get(ident);
						if (field != null) {
							// found a field
							var eobj = {
								kind: TOImplicitClass(currentClass),
								type: TTStatic(currentClass),
							};
							var type = getFieldType(field);
							return mk(TEField(eobj, ident, i), type, expectedType);
						}
						for (ext in c.extensions) {
							var e = loop(structure.getClass(ext));
							if (e != null) {
								return e;
							}
						}
						return null;
					}
					var eField = loop(currentClass);
					if (eField != null) {
						return eField;
					}
				}

				var dotPath = {first: i, rest: []};

				var decl = currentModule.getDecl(ident);
				if (decl != null) {
					return mkDeclRef(dotPath, decl, expectedType);
				}

				for (i in currentModule.imports) {
					switch (i) {
						case SISingle(pack, name):
							if (name == ident) {
								return mkDeclRef(dotPath, structure.getDecl(pack, name), expectedType);
							}
						case SIAll(pack):
							switch structure.packages[pack] {
								case null:
								case p:
									var m = p.getModule(ident);
									if (m != null) {
										return mkDeclRef(dotPath, m.mainDecl, expectedType);
									}
							}
					}
				}

				var modInPack = currentModule.pack.getModule(ident);
				if (modInPack != null) {
					return mkDeclRef(dotPath, modInPack.mainDecl, expectedType);
				}

				switch structure.packages[""] {
					case null:
					case pack:
						var toplevel = pack.getModule(ident);
						if (toplevel != null) {
							return mkDeclRef(dotPath, toplevel.mainDecl, expectedType);
						}
				}

				return null;
		}
	}

	function typeIdent(i:Token, e:Expr, expectedType:TType):TExpr {
		var e = tryTypeIdent(i, expectedType);
		if (e == null) throw 'Unknown ident: ${i.text}';
		return e;
	}

	function typeLiteral(l:Literal, expectedType:TType):TExpr {
		return switch (l) {
			case LString(t): mk(TELiteral(TLString(t)), TTString, expectedType);
			case LDecInt(t) | LHexInt(t): mk(TELiteral(TLInt(t)), TTInt, expectedType);
			case LFloat(t): mk(TELiteral(TLNumber(t)), TTNumber, expectedType);
			case LRegExp(t): mk(TELiteral(TLRegExp(t)), TTRegExp, expectedType);
		}
	}

	inline function mkExplicitFieldAccess(obj:TExpr, dot:Token, fieldToken:Token, type:TType, expectedType:TType):TExpr {
		return mk(TEField({kind: TOExplicit(dot, obj), type: obj.type}, fieldToken.text, fieldToken), type, expectedType);
	}

	function getTypedField(obj:TExpr, dot:Token, fieldToken:Token, expectedType:TType) {
		var fieldName = fieldToken.text;
		var type =
			switch [fieldName, skipParens(obj)] {
				case [_, {type: TTInt | TTUint | TTNumber}]: getNumericInstanceFieldType(fieldToken, obj.type);
				case ["toString", _]: TTFun([], TTString);
				case ["hasOwnProperty", _]: TTFun([TTString], TTBoolean);
				case ["prototype", _]: TTObject;
				case [_, {kind: TEBuiltin(_, "Array")}]: getArrayStaticFieldType(fieldToken);
				case [_, {kind: TEBuiltin(_, "Number")}]: getNumericStaticFieldType(fieldToken, TTNumber);
				case [_, {kind: TEBuiltin(_, "int")}]: getNumericStaticFieldType(fieldToken, TTInt);
				case [_, {kind: TEBuiltin(_, "uint")}]: getNumericStaticFieldType(fieldToken, TTUint);
				case [_, {kind: TEBuiltin(_, "String")}]: getStringStaticFieldType(fieldToken);
				case [_, {type: TTAny | TTObject}]: TTAny; // untyped field access
				case [_, {type: TTBuiltin | TTVoid | TTBoolean | TTClass}]: err('Attempting to get field on type ${obj.type.getName()}', fieldToken.pos); TTAny;
				case [_, {type: TTString}]: getStringInstanceFieldType(fieldToken);
				case [_, {type: TTArray}]: getArrayInstanceFieldType(fieldToken);
				case [_, {type: TTVector(t)}]: getVectorInstanceFieldType(fieldToken, t);
				case [_, {type: TTFunction | TTFun(_)}]: getFunctionInstanceFieldType(fieldToken);
				case [_, {type: TTRegExp}]: getRegExpInstanceFieldType(fieldToken);
				case [_, {type: TTXML}]:
					return typeXMLFieldAccess(obj, dot, fieldToken, expectedType);
				case [_, {type: TTXMLList}]:
					return typeXMLListFieldAccess(obj, dot, fieldToken, expectedType);
				case [_, {type: TTInst(cls)}]: typeInstanceField(cls, fieldName);
				case [_, {type: TTStatic(cls)}]: typeStaticField(cls, fieldName);
		}
		return mkExplicitFieldAccess(obj, dot, fieldToken, type, expectedType);
	}

	function typeXMLFieldAccess(xml:TExpr, dot:Token, field:Token, expectedType:TType):TExpr {
		var fieldType = switch field.text {
			case "addNamespace": TTFun([TTObject], TTXML);
			case "appendChild": TTFun([TTObject], TTXML);
			case "attribute": TTFun([TTAny], TTXMLList);
			case "attributes": TTFun([], TTXMLList);
			case "child": TTFun([TTObject], TTXMLList);
			case "childIndex": TTFun([], TTInt);
			case "children": TTFun([], TTXMLList);
			case "comments": TTFun([], TTXMLList);
			case "contains": TTFun([TTXML], TTBoolean);
			case "copy": TTFun([], TTXML);
			case "descendants": TTFun([TTObject], TTXMLList);
			case "elements": TTFun([TTObject], TTXMLList);
			case "length": TTFun([], TTInt);
			case "toXMLString": TTFun([], TTString);
			case _: null;
		}
		if (fieldType != null) {
			return mkExplicitFieldAccess(xml, dot, field, TTFun([TTObject], TTXML), expectedType);
		} else {
			// err('TODO XML instance field: ${field.text} assumed to be a child', field.pos);
			return mk(TEXmlChild({syntax: {dot: dot, name: field}, eobj: xml, name: field.text}), TTXMLList, expectedType);
		}
	}

	function typeXMLListFieldAccess(xml:TExpr, dot:Token, field:Token, expectedType:TType):TExpr {
		var fieldType = switch field.text {
			case "attribute": TTFun([], TTString);
			case "toXMLString": TTFun([], TTString);
			case _: null;
		}
		if (fieldType != null) {
			return mkExplicitFieldAccess(xml, dot, field, TTFun([TTObject], TTXML), expectedType);
		} else {
			// err('TODO XMLList instance field: ${field.text} assumed to be a child', field.pos);
			return mk(TEXmlChild({syntax: {dot: dot, name: field}, eobj: xml, name: field.text}), TTXMLList, expectedType);
		}
	}

	function getFunctionInstanceFieldType(field:Token):TType {
		return switch field.text {
			case "call" | "apply": TTFunction;
			case other: err('Unknown Function instance field: $other', field.pos); TTAny;
		}
	}

	function getRegExpInstanceFieldType(field:Token):TType {
		return switch field.text {
			case "test": TTFun([TTString], TTBoolean);
			case "exec": TTFun([TTString], TTObject);
			case other: err('Unknown RegExp instance field: $other', field.pos); TTAny;
		}
	}

	function getStringStaticFieldType(field:Token):TType {
		return switch field.text {
			case "fromCharCode": TTFun([TTInt], TTString);
			case other: err('Unknown static String field: $other', field.pos); TTAny;
		}
	}

	function getArrayStaticFieldType(field:Token):TType {
		return switch field.text {
			case "NUMERIC": TTUint;
			case "DESCENDING": TTUint;
			case "CASEINSENSITIVE": TTUint;
			case "UNIQUESORT": TTUint;
			case "RETURNINDEXEDARRAY": TTUint;
			case other: err('Unknown Array static field $other', field.pos); TTAny;
		}
	}

	function getArrayInstanceFieldType(field:Token):TType {
		return switch field.text {
			case "length": TTUint;
			case "join": TTFun([TTAny], TTString);
			case "push" | "unshift": TTFun([TTAny], TTUint, TRestSwc);
			case "pop" | "shift": TTFun([], TTAny);
			case "concat": TTFun([TTArray], TTArray);
			case "indexOf" | "lastIndexOf": TTFun([TTAny, TTInt], TTInt);
			case "slice": TTFun([TTInt, TTInt], TTArray);
			case "splice": TTFun([TTInt, TTUint, TTAny], TTArray);
			case "sort": TTFun([TTAny], TTArray);
			case "sortOn": TTFun([TTString, TTObject], TTArray);
			case other: err('Unknown Array instance field $other', field.pos); TTAny;
		}
	}

	function getVectorInstanceFieldType(field:Token, t:TType):TType {
		return switch field.text {
			case "length": TTUint;
			case "push" | "unshift": TTFun([t], TTUint, TRestSwc);
			case "pop" | "shift": TTFun([], t);
			case "indexOf" | "lastIndexOf": TTFun([t, TTInt], TTInt);
			case "splice": TTFun([TTInt, TTUint, t], TTVector(t));
			case "slice": TTFun([TTInt, TTInt], TTVector(t));
			case "join": TTFun([TTString], TTString);
			case "sort": TTFun([TTAny], TTVector(t));
			case "concat": TTFun([TTVector(t)], TTVector(t));
			case "reverse": TTFun([], TTVector(t));
			case "forEach": TTFun([TTFunction, TTObject], TTVoid);
			case other: err('Unknown Vector instance field $other', field.pos); TTAny;
		}
	}

	function getStringInstanceFieldType(field:Token):TType {
		return switch field.text {
			case "length": TTInt;
			case "substr" | "substring" | "slice": TTFun([TTNumber, TTNumber], TTString);
			case "toLowerCase" | "toUpperCase" | "toLocaleLowerCase" | "toLocaleUpperCase": TTFun([], TTString);
			case "indexOf" | "lastIndexOf": TTFun([TTString, TTNumber], TTInt);
			case "split": TTFun([TTAny, TTNumber], TTArray);
			case "charAt": TTFun([TTNumber], TTString);
			case "charCodeAt": TTFun([TTNumber], TTNumber);
			case "concat": TTFun([TTAny], TTString);
			case "search": TTFun([TTAny], TTInt);
			case "replace": TTFun([TTAny, TTObject], TTString);
			case "match": TTFun([TTAny], TTArray);
			case other: err('Unknown String instance field $other', field.pos); TTAny;
		}
	}

	function getNumericInstanceFieldType(field:Token, type:TType):TType {
		return switch field.text {
			case "toString": TTFun([TTUint], TTString);
			case "toFixed": TTFun([TTUint], TTString);
			case other: err('Unknown field $other on type ${type.getName()}', field.pos); TTAny;
		}
	}

	function getNumericStaticFieldType(field:Token, type:TType):TType {
		return switch field.text {
			case "MIN_VALUE": type;
			case "MAX_VALUE": type;
			case other: err('Unknown field $other on type ${type.getName()}', field.pos); TTAny;
		}
	}

	function typeField(eobj:Expr, dot:Token, name:Token, expectedType:TType):TExpr {
		switch exprToDotPath(eobj) {
			case null:
			case prefixDotPath:
				var e = tryTypeIdent(prefixDotPath.first, TTAny);
				if (e == null) @:nullSafety(Off) {
					// probably a fully-qualified type path then

					var acc = [{dot: null, token: prefixDotPath.first}];
					for (r in prefixDotPath.rest) acc.push({dot: r.sep, token: r.element});

					var declName = {dot: dot, token: name};
					var decl = null;
					var rest = [];
					while (acc.length > 0) {
						var packName = [for (t in acc) t.token.text].join(".");
						var pack = structure.packages[packName];
						if (pack != null) {
							var mod = pack.getModule(declName.token.text);
							decl = mod.mainDecl;
							break;
						} else {
							rest.push(declName);
							declName = acc.pop();
						}
					}

					if (decl == null) {
						throw "unknown declaration";
					}

					acc.push(declName);
					var dotPath = {
						first: acc[0].token,
						rest: [for (i in 1...acc.length) {sep: acc[i].dot, element: acc[i].token}]
					};

					var expr = mkDeclRef(dotPath, decl, if (rest.length == 0) expectedType else TTAny);

					while (rest.length > 0) {
						var f = rest.pop();
						expr = getTypedField(expr, f.dot, f.token, if (rest.length == 0) expectedType else TTAny);
					}

					return expr;
				}
		}

		// TODO: we don't need to re-type stuff,
		// can iterate over fields, but let's do it later :-)

		var eobj = typeExpr(eobj, TTAny);
		return getTypedField(eobj, dot, name, expectedType);
	}

	function typeInstanceField(cls:SClassDecl, fieldName:String):TType {
		function loop(cls:SClassDecl):Null<SClassField> {
			var field = cls.fields.get(fieldName);
			if (field != null) {
				return field;
			}
			for (ext in cls.extensions) {
				var field = loop(structure.getClass(ext));
				if (field != null) {
					return field;
				}
			}
			return null;
		}

		var field = loop(cls);
		if (field != null) {
			return getFieldType(field);
		}

		throw 'Unknown instance field $fieldName on class ${cls.name}';
	}

	function typeStaticField(cls:SClassDecl, fieldName:String):TType {
		var field = cls.statics.get(fieldName);
		if (field != null) {
			return getFieldType(field);
		}
		throw 'Unknown static field $fieldName on class ${cls.name}';
	}

	function typeObjectDecl(openBrace:Token, fields:Separated<ObjectField>, closeBrace:Token, expectedType:TType):TExpr {
		var fields = separatedToArray(fields, function(f, comma) {
			return {
				syntax: {name: f.name, colon: f.colon, comma: comma},
				name: f.name.text,
				expr: typeExpr(f.value, TTAny)
			};
		});
		return mk(TEObjectDecl({
			syntax: {openBrace: openBrace, closeBrace: closeBrace},
			fields: fields
		}), TTObject, expectedType);
	}

	function typeVarInit(init:VarInit, expectedType:TType):TVarInit {
		return {equals: init.equals, expr: typeExpr(init.expr, expectedType)};
	}

	function typeVars(kind:VarDeclKind, vars:Separated<VarDecl>, expectedType:TType):TExpr {
		switch expectedType {
			case TTAny: // for (var i)
			case TTVoid: // block-level vars
			case _: throw "assert"; // should NOT happen
		}

		var vars = separatedToArray(vars, function(v, comma) {
			var type = if (v.type == null) TTAny else resolveType(v.type.type);
			var init = if (v.init != null) typeVarInit(v.init, type) else null;
			var tvar = addLocal(v.name.text, type);
			return {
				syntax: v,
				v: tvar,
				init: init,
				comma: comma,
			};
		});
		return mk(TEVars(kind, vars), TTVoid, expectedType);
	}
}
