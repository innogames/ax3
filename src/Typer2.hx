import ParseTree;
import ParseTree.*;
import Structure;

@:nullSafety
class Typer2 {
	final structure:Structure;

	public function new(structure) {
		this.structure = structure;
	}

	@:nullSafety(Off) var currentModule:SModule;

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
		// trace("cls", c.name.text);
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
			case FFun(keyword, name, fun):
				// trace(" - " + name.text);
				typeFunction(fun);
			case FProp(keyword, kind, name, fun):
		}
	}

	function typeFunction(fun:Function) {
		typeExpr(EBlock(fun.block));
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
			resolveType(c.type.type);
			typeExpr(EBlock(c.block));
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
		for (e in b.exprs) {
			typeExpr(e.expr);
		}
	}

	function typeArrayAccess(e:Expr, eindex:Expr) {
		typeExpr(e);
		typeExpr(eindex);
	}

	function typeArrayDecl(d:ArrayDecl) {
		if (d.elems != null) iterSeparated(d.elems, typeExpr);
	}

	function typeIdent(i:Token) {

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
		});
	}
}
