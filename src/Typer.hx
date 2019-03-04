import ParseTree;
import ParseTree.*;
import Structure;
import TypedTree;

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

	function addLocal(name:String, type:TType) {
		locals[name] = {name: name, type: type};
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

	function typeFunction(fun:Function) {
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
	}

	function typeExpr(e:Expr) {
		switch (e) {
			case EIdent(i): typeIdent(i, e);
			case ELiteral(l): typeLiteral(l);
			case ECall(e, args): typeCall(e, args);
			case EParens(openParen, e, closeParen): typeExpr(e);
			case EArrayAccess(e, openBracket, eindex, closeBracket): typeArrayAccess(e, eindex);
			case EArrayDecl(d): typeArrayDecl(d);
			case EReturn(keyword, e): if (e != null) typeExpr(e);
			case EThrow(keyword, e): typeExpr(e);
			case EDelete(keyword, e): typeExpr(e);
			case ENew(keyword, e, args): typeNew(e, args);
			case EVectorDecl(newKeyword, t, d): typeArrayDecl(d);
			case EField(eobj, dot, fieldName): typeField(eobj, fieldName, e);
			case EBlock(b): typeBlock(b);
			case EObjectDecl(openBrace, fields, closeBrace): typeObjectDecl(fields);
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
			case EVector(v): resolveType(v.t.type);
			case ESwitch(keyword, openParen, subj, closeParen, openBrace, cases, closeBrace): typeSwitch(subj, cases);
			case ETry(keyword, block, catches, finally_): typeTry(block, catches, finally_);
			case EFunction(keyword, name, fun): typeFunction(fun);

			case EBreak(keyword):
			case EContinue(keyword):

			case EXmlAttr(e, dot, at, attrName):
			case EXmlDescend(e, dotDot, childName):
			case ECondCompValue(v):
			case ECondCompBlock(v, b):
			case EUseNamespace(n):
		}
	}

	function typeTry(block:BracedExprBlock, catches:Array<Catch>, finally_:Null<Finally>) {
		if (finally_ != null) throw "finally is unsupported";
		typeExpr(EBlock(block));
		for (c in catches) {
			pushLocals();
			addLocal(c.name.text, resolveType(c.type.type));
			resolveType(c.type.type);
			typeExpr(EBlock(c.block));
			popLocals();
		}
	}

	function typeSwitch(subj:Expr, cases:Array<SwitchCase>) {
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
	}

	function typeAs(e:Expr, t:SyntaxType) {
		typeExpr(e);
		resolveType(t);
	}

	function typeIs(e:Expr, t:SyntaxType) {
		typeExpr(e);
		// resolveType(t); // TODO: this can be also an expr O_o
	}

	function typeComma(a:Expr, b:Expr) {
		typeExpr(a);
		typeExpr(b);
	}

	function typeBinop(a:Expr, op:Binop, b:Expr) {
		typeExpr(a);
		typeExpr(b);
	}

	function typeForIn(iter:ForIter, body:Expr) {
		typeExpr(iter.eobj);
		typeExpr(iter.eit);
		typeExpr(body);
	}

	function typeFor(einit:Null<Expr>, econd:Null<Expr>, eincr:Null<Expr>, body:Expr) {
		if (einit != null) typeExpr(einit);
		if (econd != null) typeExpr(econd);
		if (eincr != null) typeExpr(eincr);
		typeExpr(body);
	}

	function typeWhile(econd:Expr, ebody:Expr) {
		typeExpr(econd);
		typeExpr(ebody);
	}

	function typeDoWhile(ebody:Expr, econd:Expr) {
		typeExpr(ebody);
		typeExpr(econd);
	}

	function typeIf(econd:Expr, ethen:Expr, eelse:Null<{keyword:Token, expr:Expr}>) {
		typeExpr(econd);
		typeExpr(ethen);
		if (eelse != null) {
			typeExpr(eelse.expr);
		}
	}

	function typeTernary(econd:Expr, ethen:Expr, eelse:Expr) {
		typeExpr(econd);
		typeExpr(ethen);
		typeExpr(eelse);
	}

	function typeCall(e:Expr, args:CallArgs) {
		typeExpr(e);
		if (args.args != null) iterSeparated(args.args, typeExpr);
	}

	function typeNew(e:Expr, args:Null<CallArgs>) {
		typeExpr(e);
		if (args != null && args.args != null) iterSeparated(args.args, typeExpr);
	}

	function typeBlock(b:BracedExprBlock) {
		pushLocals();
		for (e in b.exprs) {
			typeExpr(e.expr);
		}
		popLocals();
	}

	function typeArrayAccess(e:Expr, eindex:Expr) {
		typeExpr(e);
		typeExpr(eindex);
	}

	function typeArrayDecl(d:ArrayDecl) {
		if (d.elems != null) iterSeparated(d.elems, typeExpr);
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
			case "super": mk(TEThis(e), TTInst(structure.getClass(getCurrentClass("super").extensions[0])));
			case "true" | "false": mk(TELiteral(TLBool(i)), TTBoolean);
			case "null": mk(TELiteral(TLNull(i)), TTAny);
			case "undefined": mk(TELiteral(TLUndefined(i)), TTAny);
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

	function typeField(eobj:Expr, name:Token, e:Expr) {
		typeExpr(eobj);
	}

	function typeObjectDecl(fields:Separated<ObjectField>) {
		iterSeparated(fields, f -> typeExpr(f.value));
	}

	function typeVars(vars:Separated<VarDecl>) {
		iterSeparated(vars, function(v) {
			var type = if (v.type == null) TTAny else resolveType(v.type.type);
			if (v.init != null) {
				typeExpr(v.init.expr);
			}
			addLocal(v.name.text, type);
		});
	}
}
