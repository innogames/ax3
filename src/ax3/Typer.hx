package ax3;

import ax3.ParseTree;
import ax3.ParseTree.*;
import ax3.Structure;
import ax3.TypedTree;

typedef Locals = Map<String, TVar>;

@:nullSafety
class Typer {
	final structure:Structure;

	@:nullSafety(Off) var locals:Locals;
	@:nullSafety(Off) var localsStack:Array<Locals>;

	public function new(structure) {
		this.structure = structure;
	}

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

	@:nullSafety(Off) var currentModule:SModule;
	var currentClass:Null<SClassDecl>;

	public function process(files:Array<File>) {
		for (file in files) {

			var pack = getPackageDecl(file);

			var mainDecl = getPackageMainDecl(pack);

			var privateDecls = getPrivateDecls(file);

			var imports = getImports(file);

			// TODO: just skipping conditional-compiled ones for now
			if (mainDecl == null) continue;

			var packName = if (pack.name == null) "" else dotPathToString(pack.name);
			var currentPackage = structure.packages[packName];
			if (currentPackage == null) throw "assert";

			var mod = currentPackage.getModule(file.name);
			if (mod == null) throw "assert";
			currentModule = mod;

			switch (mainDecl) {
				case DPackage(p):
				case DImport(i):
				case DClass(c):
					switch currentModule.getMainClass(c.name.text) {
						case null: throw "assert";
						case cls: currentClass = cls;
					}
					typeClass(c);
					currentClass = null;
				case DInterface(i):
				case DFunction(f):
				case DVar(v):
				case DNamespace(ns):
				case DUseNamespace(n, semicolon):
				case DCondComp(v, openBrace, decls, closeBrace):
			}

		}
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
			case STUnresolved(path):  throw "Unresolved type " + path;
		}
	}

	function resolveType(t:SyntaxType):TType {
		return typeType(structure.buildTypeStructure(t, currentModule));
	}

	inline function mk(e:TExprKind, t:TType):TExpr return {kind: e, type: t};

	function typeClass(c:ClassDecl) {
		trace("cls", c.name.text);

		for (m in c.members) {
			switch (m) {
				case MCondComp(v, openBrace, members, closeBrace):
				case MUseNamespace(n, semicolon):
				case MField(f):
					typeClassField(f);
				case MStaticInit(block):
			}
		}
	}

	function typeClassField(f:ClassField) {
		switch (f.kind) {
			case FVar(kind, vars, semicolon):
				iterSeparated(vars, function(v) {
					// TODO: check what is allowed to be resolved
					if (v.init != null) typeExpr(v.init.expr);
				});
			case FFun(keyword, name, fun):
				trace(" - " + name.text);
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				typeFunction(fun);
			case FProp(keyword, kind, name, fun):
				trace(" - " + name.text);
				initLocals();
				// TODO: can use structure to get arg types (speedup \o/)
				typeFunction(fun);
		}
	}

	function typeFunction(fun:Function):TExpr {
		pushLocals();

		if (fun.signature.args != null) {
			iterSeparated(fun.signature.args, function(arg) {
				switch (arg) {
					case ArgNormal(a):
						var type = if (a.type == null) TTAny else resolveType(a.type.type);
						addLocal(a.name.text, type);
					case ArgRest(dots, name):
						addLocal(name.text, TTArray);
				}
			});
		}

		typeExpr(EBlock(fun.block));
		popLocals();

		return mk(null, TTFunction); // TODO: return TTFun instead (we need to coerce args on call)
	}

	function typeExpr(e:Expr):TExpr {
		return switch (e) {
			case EIdent(i): typeIdent(i, e);
			case ELiteral(l): typeLiteral(l);
			case ECall(e, args): typeCall(e, args);
			case EParens(openParen, e, closeParen): typeExpr(e);
			case EArrayAccess(e, openBracket, eindex, closeBracket): typeArrayAccess(e, eindex);
			case EArrayDecl(d): typeArrayDecl(d);
			case EVectorDecl(newKeyword, t, d): typeVectorDecl(t.type, d);
			case EReturn(keyword, e): mk(TEReturn(keyword, if (e != null) typeExpr(e) else null), TTVoid);
			case EThrow(keyword, e): mk(TEThrow(keyword, typeExpr(e)), TTVoid);
			case EDelete(keyword, e): mk(TEDelete(keyword, typeExpr(e)), TTVoid);
			case ENew(keyword, e, args): typeNew(e, args);
			case EField(eobj, dot, fieldName): typeField(eobj, fieldName, e);
			case EBlock(b): typeBlock(b);
			case EObjectDecl(openBrace, fields, closeBrace): typeObjectDecl(e, fields);
			case EIf(keyword, openParen, econd, closeParen, ethen, eelse): typeIf(econd, ethen, eelse);
			case ETernary(econd, question, ethen, colon, eelse): typeTernary(econd, ethen, eelse);
			case EWhile(keyword, openParen, cond, closeParen, body): typeWhile(cond, body);
			case EDoWhile(doKeyword, body, whileKeyword, openParen, cond, closeParen): typeDoWhile(body, cond);
			case EFor(keyword, openParen, einit, initSep, econd, condSep, eincr, closeParen, body): typeFor(einit, econd, eincr, body);
			case EForIn(forKeyword, openParen, iter, closeParen, body): typeForIn(iter, body);
			case EForEach(forKeyword, eachKeyword, openParen, iter, closeParen, body): typeForIn(iter, body);
			case EBinop(a, op, b): typeBinop(a, op, b);
			case EPreUnop(op, e): typeExpr(e);
			case EPostUnop(e, op): typeExpr(e);
			case EVars(kind, vars): typeVars(vars);
			case EAs(e, keyword, t): typeAs(e, t);
			case EIs(e, keyword, t): typeIs(e, t);
			case EComma(a, comma, b): typeComma(a, b);
			case EVector(v): typeVector(v);
			case ESwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace): typeSwitch(subj, cases);
			case ETry(keyword, block, catches, finally_): typeTry(block, catches, finally_);
			case EFunction(keyword, name, fun): typeFunction(fun);

			case EBreak(keyword): mk(TEBreak(keyword), TTVoid);
			case EContinue(keyword): mk(TEContinue(keyword), TTVoid);

			case EXmlAttr(e, dot, at, attrName): null;
			case EXmlDescend(e, dotDot, childName): null;
			case ECondCompValue(v): null;
			case ECondCompBlock(v, b): null;
			case EUseNamespace(n): null;
		}
	}

	function typeVector(v:VectorSyntax):TExpr {
		var type = resolveType(v.t.type);
		return mk(TEVector(type), TTFunction);
	}

	function typeTry(block:BracedExprBlock, catches:Array<Catch>, finally_:Null<Finally>):TExpr {
		if (finally_ != null) throw "finally is unsupported";
		var body = typeExpr(EBlock(block));
		var tCatches = [];
		for (c in catches) {
			pushLocals();
			var v = addLocal(c.name.text, resolveType(c.type.type));
			var e = typeExpr(EBlock(c.block));
			popLocals();
			tCatches.push({v: v, expr: e});
		}
		return mk(TETry(body, tCatches), TTVoid);
	}

	function typeSwitch(subj:Expr, cases:Array<SwitchCase>):TExpr {
		typeExpr(subj);
		for (c in cases) {
			switch (c) {
				case CCase(keyword, v, colon, body):
					typeExpr(v);
					for (e in body) {
						typeExpr(e.expr);
					}
				case CDefault(keyword, colon, body):
					for (e in body) {
						typeExpr(e.expr);
					}
			}
		}
		return mk(null, TTVoid);
	}

	function typeAs(e:Expr, t:SyntaxType) {
		typeExpr(e);
		var type = resolveType(t);
		return mk(null, type);
	}

	function typeIs(e:Expr, t:SyntaxType):TExpr {
		typeExpr(e);
		// resolveType(t); // TODO: this can be also an expr O_o
		return mk(null, TTBoolean);
	}

	function typeComma(a:Expr, b:Expr):TExpr {
		var a = typeExpr(a);
		var b = typeExpr(b);
		return mk(null, b.type);
	}

	function typeBinop(a:Expr, op:Binop, b:Expr):TExpr {
		typeExpr(a);
		typeExpr(b);
		return cast null;
	}

	function typeForIn(iter:ForIter, body:Expr):TExpr {
		typeExpr(iter.eobj);
		typeExpr(iter.eit);
		typeExpr(body);
		return mk(null, TTVoid);
	}

	function typeFor(einit:Null<Expr>, econd:Null<Expr>, eincr:Null<Expr>, body:Expr):TExpr {
		if (einit != null) typeExpr(einit);
		if (econd != null) typeExpr(econd);
		if (eincr != null) typeExpr(eincr);
		typeExpr(body);
		return mk(null, TTVoid);
	}

	function typeWhile(econd:Expr, ebody:Expr):TExpr {
		var econd = typeExpr(econd);
		var ebody = typeExpr(ebody);
		return mk(TEWhile(econd, ebody), TTVoid);
	}

	function typeDoWhile(ebody:Expr, econd:Expr):TExpr {
		var ebody = typeExpr(ebody);
		var econd = typeExpr(econd);
		return mk(TEDoWhile(ebody, econd), TTVoid);
	}

	function typeIf(econd:Expr, ethen:Expr, eelse:Null<{keyword:Token, expr:Expr}>):TExpr {
		var econd = typeExpr(econd);
		var ethen = typeExpr(ethen);
		var eelse = if (eelse != null) typeExpr(eelse.expr) else null;
		return mk(TEIf(econd, ethen, eelse), TTVoid);
	}

	function typeTernary(econd:Expr, ethen:Expr, eelse:Expr):TExpr {
		var econd = typeExpr(econd);
		var ethen = typeExpr(ethen);
		var eelse = typeExpr(eelse);
		return mk(TETernary(econd, ethen, eelse), ethen.type);
	}

	function typeCall(e:Expr, args:CallArgs) {
		var eobj = typeExpr(e);
		var callArgs = if (args.args != null) foldSeparated(args.args, [], (e,acc) -> acc.push(typeExpr(e))) else [];
		var type =
			if (eobj == null) TTAny else // TODO: remove this
			switch (eobj.type) {
			case TTAny | TTFunction: TTAny;
			case TTFun(_, ret): ret;
			case TTStatic(cls): TTInst(cls); // ClassName(expr) cast (TODO: this should be TESafeCast expression)
			case other: trace("unknown callable type: " + other); TTAny; // TODO: super, builtins, etc.
		};
		return mk(TECall({eobj: e, args: args}, eobj, callArgs), type);
	}

	function typeNew(e:Expr, args:Null<CallArgs>):TExpr {
		typeExpr(e);
		if (args != null && args.args != null) iterSeparated(args.args, typeExpr);
		return cast null;
	}

	function typeBlock(b:BracedExprBlock):TExpr {
		pushLocals();
		var exprs = [];
		for (e in b.exprs) {
			exprs.push(typeExpr(e.expr));
		}
		popLocals();
		return mk(TEBlock(b, exprs), TTVoid);
	}

	function typeArrayAccess(e:Expr, eindex:Expr):TExpr {
		var e = typeExpr(e);
		var eindex = typeExpr(eindex);
		var type = switch (e.type) {
			case TTVector(t): t;
			case _: TTAny;
		};
		return mk(TEArrayAccess(e, eindex), type);
	}

	function typeArrayDecl(d:ArrayDecl):TExpr {
		var elems = if (d.elems != null) foldSeparated(d.elems, [], function(e, acc) acc.push(typeExpr(e))) else [];
		return mk(TEArrayDecl(d, elems), TTArray);
	}

	function typeVectorDecl(t:SyntaxType, d:ArrayDecl):TExpr {
		var type = resolveType(t);
		var elems = if (d.elems != null) foldSeparated(d.elems, [], function(e, acc) acc.push(typeExpr(e))) else [];
		return mk(TEVectorDecl(type, elems), TTVector(type));
	}

	function getTypeOfFunctionDecl(f:SFunDecl):TType {
		return TTFun([for (a in f.args) typeType(a.type)], typeType(f.ret));
	}

	function mkDeclRef(decl:SDecl):TExpr {
		var type = switch (decl.kind) {
			case SVar(v): typeType(v.type);
			case SFun(f): getTypeOfFunctionDecl(f);
			case SClass(c): TTStatic(c);
		};
		return mk(TEDeclRef(decl), type);
	}

	function typeIdent(i:Token, e:Expr):TExpr {
		inline function getCurrentClass(subj) return if (currentClass != null) currentClass else throw '`$subj` used outside of class';

		return switch i.text {
			case "this": mk(TEThis(e), TTInst(getCurrentClass("this")));
			case "super": mk(TESuper(e), TTInst(structure.getClass(getCurrentClass("super").extensions[0])));
			case "true" | "false": mk(TELiteral(TLBool(i)), TTBoolean);
			case "null": mk(TELiteral(TLNull(i)), TTAny);
			case "undefined": mk(TELiteral(TLUndefined(i)), TTAny);
			case "arguments": mk(TEBuiltin(i, "arguments"), TTBuiltin);
			case "trace": mk(TEBuiltin(i, "trace"), TTFunction);
			case "int": mk(TEBuiltin(i, "int"), TTBuiltin);
			case "uint": mk(TEBuiltin(i, "int"), TTBuiltin);
			case "Boolean": mk(TEBuiltin(i, "Boolean"), TTBuiltin);
			case "Number": mk(TEBuiltin(i, "Number"), TTBuiltin);
			case "XML": mk(TEBuiltin(i, "XML"), TTBuiltin);
			case "XMLList": mk(TEBuiltin(i, "XMLList"), TTBuiltin);
			case "String": mk(TEBuiltin(i, "String"), TTBuiltin);
			case "Array": mk(TEBuiltin(i, "Array"), TTBuiltin);
			case "Function": mk(TEBuiltin(i, "Function"), TTBuiltin);
			case "Class": mk(TEBuiltin(i, "Class"), TTBuiltin);
			case "Object": mk(TEBuiltin(i, "Object"), TTBuiltin);
			case "RegExp": mk(TEBuiltin(i, "RegExp"), TTBuiltin);
			// TODO: actually these must be resolved after everything because they are global idents!!!
			case "parseInt":  mk(TEBuiltin(i, "parseInt"), TTFun([TTString], TTInt));
			case "parseFloat": mk(TEBuiltin(i, "parseFloat"), TTFun([TTString], TTNumber));
			case "NaN": mk(TEBuiltin(i, "NaN"), TTNumber);
			case "isNaN": mk(TEBuiltin(i, "isNaN"), TTFun([TTNumber], TTBoolean));
			case "escape": mk(TEBuiltin(i, "escape"), TTFun([TTString], TTString));
			case "unescape": mk(TEBuiltin(i, "unescape"), TTFun([TTString], TTString));
			case ident:
				var v = locals[ident];
				if (v != null) {
					return mk(TELocal(i, v), v.type);
				}

				if (currentClass != null) {
					var currentClass:SClassDecl = currentClass; // TODO: this is here only to please the null-safety checker
					function loop(c:SClassDecl):Null<TExpr> {
						var field = c.getField(ident);
						if (field != null) {
							// found a field
							var eobj = mk(TEThis(null), TTInst(currentClass));
							var type = switch (field.kind) {
								case SFVar(v): typeType(v.type);
								case SFFun(f): getTypeOfFunctionDecl(f);
							};
							return mk(TEField(e, eobj, ident), type);
						}
						for (ext in c.extensions) {
							var e = loop(structure.getClass(ext));
							if (e != null) {
								return e;
							}
						}
						return null;
					}
					var e = loop(currentClass);
					if (e != null) {
						return e;
					}
				}

				var decl = currentModule.getDecl(ident);
				if (decl != null) {
					return mkDeclRef(decl);
				}

				for (i in currentModule.imports) {
					switch (i) {
						case SISingle(pack, name):
							if (name == ident) {
								// trace('Found imported decl: $pack::$name');
								return mkDeclRef(structure.getDecl(pack, name));
							}
						case SIAll(pack):
							switch structure.packages[pack] {
								case null:
								case p:
									var m = p.getModule(ident);
									if (m != null) {
										// trace('Found imported decl: $pack::$ident');
										return mkDeclRef(m.mainDecl);
									}
							}
					}
				}

				var modInPack = currentModule.pack.getModule(ident);
				if (modInPack != null) {
					return mkDeclRef(modInPack.mainDecl);
				}

				switch structure.packages[""] {
					case null:
					case pack:
						var toplevel = pack.getModule(ident);
						if (toplevel != null) {
							return mkDeclRef(toplevel.mainDecl);
						}
				}

				throw 'Unknown ident: $ident';
		}
	}

	function typeLiteral(l:Literal):TExpr {
		return switch (l) {
			case LString(t): mk(TELiteral(TLString(t)), TTString);
			case LDecInt(t) | LHexInt(t): mk(TELiteral(TLInt(t)), TTInt);
			case LFloat(t): mk(TELiteral(TLNumber(t)), TTNumber);
			case LRegExp(t): mk(TELiteral(TLRegExp(t)), TTRegExp);
		}
	}

	function typeField(eobj:Expr, name:Token, e:Expr):TExpr {
		typeExpr(eobj);
		return cast null;
	}

	function typeObjectDecl(e:Expr, fields:Separated<ObjectField>):TExpr {
		var fields = foldSeparated(fields, [], (f,acc) -> acc.push({syntax: f, name: f.name.text, expr: typeExpr(f.value)}));
		return mk(TEObjectDecl(e, fields), TTObject);
	}

	function typeVars(vars:Separated<VarDecl>):TExpr {
		var vars = foldSeparated(vars, [], function(v, acc) {
			var type = if (v.type == null) TTAny else resolveType(v.type.type);
			var init = if (v.init != null) typeExpr(v.init.expr) else null;
			var tvar = addLocal(v.name.text, type);
			acc.push({
				syntax: v,
				v: tvar,
				init: init
			});
		});
		return mk(TEVars(vars), TTVoid);
	}
}
