import ParseTree;
import ParseTree.*;
import Structure;

typedef Locals = Map<String, SType>;

@:nullSafety
class Typer2 {
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

	function addLocal(name, type) {
		locals[name] = type;
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
				case DInterface(i):
				case DFunction(f):
				case DVar(v):
				case DNamespace(ns):
				case DUseNamespace(n, semicolon):
				case DCondComp(v, openBrace, decls, closeBrace):
			}

		}
	}

	inline function resolveType(t:SyntaxType):SType {
		return switch structure.buildTypeStructure(t, currentModule) {
			case STUnresolved(path): throw "Unresolved type " + path;
			case resolved: resolved;
		}
	}

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
						var type = if (a.type == null) STAny else resolveType(a.type.type);
						addLocal(a.name.text, type);
					case ArgRest(dots, name):
						addLocal(name.text, STArray);
				}
			});
		}

		typeExpr(EBlock(fun.block));
		popLocals();
	}

	function typeExpr(e:Expr) {
		switch (e) {
			case EIdent(i): typeIdent(i);
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
			case EField(e, dot, fieldName): typeField(e, fieldName);
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

	function typeIdent(i:Token) {
		switch i.text {
			case "this":
			case "super":
			case "true":
			case "false":
			case "null" | "undefined":
			case "trace":
			case "int":
			case "uint":
			case "Boolean":
			case "Number":
			case "XML":
			case "XMLList":
			case "String":
			case "Array":
			case "Function":
			case "Class":
			case "Object":
			case "RegExp":
			// TODO: actually these must be resolved after everything because they are global idents!!!
			case "parseInt":
			case "parseFloat":
			case "NaN":
			case "isNaN":
			case "escape":
			case "unescape":
			case ident:
				var type = locals[ident];
				if (type != null) {
					// found a local
					// trace('Found local: $ident');
					return;
				}

				if (currentClass != null) {
					function loop(c:SClassDecl):Bool {
						var field = c.getField(ident);
						if (field != null) {
							// found a field
							// trace('Found field: $ident');
							return true;
						}
						for (ext in c.extensions) {
							if (loop(structure.getClass(ext))) {
								return true;
							}
						}
						return false;
					}
					if (loop(currentClass)) {
						return;
					}
				}

				var decl = currentModule.getDecl(ident);
				if (decl != null) {
					// trace('Found module decl: $ident');
					return;
				}

				for (i in currentModule.imports) {
					switch (i) {
						case SISingle(pack, name):
							if (name == ident) {
								// trace('Found imported decl: $pack::$name');
								return;
							}
						case SIAll(pack):
							switch structure.packages[pack] {
								case null:
								case p:
									var m = p.getModule(ident);
									if (m != null) {
										// trace('Found imported decl: $pack::$ident');
										return;
									}
							}
					}
				}

				var modInPack = currentModule.pack.getModule(ident);
				if (modInPack != null) {
					return;
				}

				switch structure.packages[""] {
					case null:
					case pack:
						var toplevel = pack.getModule(ident);
						if (toplevel != null) {
							return;
						}
				}

				trace('Unknown ident: $ident');
		}
	}

	function typeLiteral(l:Literal) {

	}

	function typeField(e:Expr, name:Token) {
		typeExpr(e);
	}

	function typeObjectDecl(fields:Separated<ObjectField>) {
		iterSeparated(fields, f -> typeExpr(f.value));
	}

	function typeVars(vars:Separated<VarDecl>) {
		iterSeparated(vars, function(v) {
			var type = if (v.type == null) STAny else resolveType(v.type.type);
			if (v.init != null) {
				typeExpr(v.init.expr);
			}
			addLocal(v.name.text, type);
		});
	}
}
