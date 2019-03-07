package ax3;

class ParseTree {
	public static function dotPathToString(d:DotPath):String {
		return dotPathToArray(d).join(".");
	}

	public static function dotPathToArray(d:DotPath):Array<String> {
		return foldSeparated(d, [], (part, acc) -> acc.push(part.text));
	}

	public static function exprToDotPath(e:Expr):Null<DotPath> {
		var acc = [];
		function loop(e:Expr) {
			switch e {
				case EIdent(i):
					acc.reverse();
					return {first: i, rest: acc};
				case EField(e, dot, fieldName):
					acc.push({sep: dot, element: fieldName});
					return loop(e);
				case _:
					return null;
			}
		}
		return loop(e);
	}

	public static function separatedToArray<T,S>(s:Separated<T>, f:(T,Null<Token>)->S):Array<S> {
		var r = [];
		var sep = if (s.rest.length > 0) s.rest[0].sep else null;
		r.push(f(s.first, sep));
		for (i in 0...s.rest.length) {
			var sep = if (i == s.rest.length - 1) null else s.rest[i + 1].sep;
			r.push(f(s.rest[i].element, sep));
		}
		return r;
	}

	public static function iterSeparated<T>(d:Separated<T>, f:T->Void) {
		f(d.first);
		for (p in d.rest) {
			f(p.element);
		}
	}

	public static function foldSeparated<T,S>(d:Separated<T>, acc:S, f:(T,S)->Void):S {
		f(d.first, acc);
		for (p in d.rest) {
			f(p.element, acc);
		}
		return acc;
	}

	public static function getPackageDecl(file:File):PackageDecl {
		var pack = null;
		for (decl in file.declarations) {
			switch (decl) {
				case DPackage(p):
					if (pack != null) throw 'Duplicate package decl in ${file.name}';
					pack = p;
				case _:
			}
		}
		if (pack == null) throw "No package declaration in " + file.name;
		return pack;
	}

	public static function getPackageMainDecl(p:PackageDecl):Declaration {
		var decl = null;

		function loop(decls:Array<Declaration>) {
			for (d in decls) {
				switch (d) {
					case DPackage(p):
						throw "Package inside package is not allowed";

					case DClass(_) | DInterface(_) | DFunction(_) | DVar(_) | DNamespace(_):
						if (decl != null) throw "More than one declaration inside package";
						decl = d;

					case DCondComp(_, _, decls, _):
						loop(decls);

					// skip these for now
					case DImport(_):
					case DUseNamespace(_):
				}
			}
		}


		loop(p.declarations);

		if (decl == null) throw "No declaration inside package";

		return decl;
	}

	public static function getPrivateDecls(file:File):Array<Declaration> {
		var decls = [];

		function loop(declarations:Array<Declaration>) {
			for (d in declarations) {
				switch (d) {
					case DPackage(p): // in-package is the main one

					case DClass(_) | DInterface(_) | DFunction(_) | DVar(_):
						decls.push(d);

					case DCondComp(_, _, decls, _):
						loop(decls);

					case DNamespace(ns):
					case DImport(i):
					case DUseNamespace(n, semicolon):
				}
			}
		}

		loop(file.declarations);

		return decls;
	}

	public static function getImports(file:File) {
		var result = [];
		function loop(decls:Array<Declaration>) {
			for (d in decls) {
				switch (d) {
					case DPackage(p): loop(p.declarations);
					case DImport(i): result.push(i);
					case DCondComp(_, _, decls, _): loop(decls);
					case _:
				}
			}
		}
		loop(file.declarations);
		return result;
	}
}

typedef File = {
	var name:String;
	var declarations:Array<Declaration>;
	var eof:Token;
}

typedef Separated<T> = {
	var first:T;
	var rest:Array<{sep:Token, element:T}>;
}

typedef DotPath = Separated<Token>;

enum Declaration {
	DPackage(p:PackageDecl);
	DImport(i:ImportDecl);
	DClass(c:ClassDecl);
	DInterface(i:InterfaceDecl);
	DFunction(f:FunctionDecl);
	DVar(v:ModuleVarDecl);
	DNamespace(ns:NamespaceDecl);
	DUseNamespace(n:UseNamespace, semicolon:Token);
	DCondComp(v:CondCompVar, openBrace:Token, decls:Array<Declaration>, closeBrace:Token);
}

typedef PackageDecl = {
	var keyword:Token;
	var name:Null<DotPath>;
	var openBrace:Token;
	var declarations:Array<Declaration>;
	var closeBrace:Token;
}

typedef NamespaceDecl = {
	var modifiers:Array<DeclModifier>;
	var keyword:Token;
	var name:Token;
	var semicolon:Token;
}

typedef ModuleVarDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var kind:VarDeclKind;
	var vars:Separated<VarDecl>;
	var semicolon:Token;
}

typedef ImportDecl = {
	var keyword:Token;
	var path:DotPath;
	var wildcard:Null<{dot:Token, asterisk:Token}>;
	var semicolon:Token;
}

typedef UseNamespace = {
	var useKeyword:Token;
	var namespaceKeyword:Token;
	var name:Token;
}

enum DeclModifier {
	DMPublic(t:Token);
	DMInternal(t:Token);
	DMFinal(t:Token);
	DMDynamic(t:Token);
}

typedef FunctionDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var keyword:Token;
	var name:Token;
	var fun:Function;
}

typedef ClassDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var keyword:Token;
	var name:Token;
	var extend:Null<{keyword:Token, path:DotPath}>;
	var implement:Null<{keyword:Token, paths:Separated<DotPath>}>;
	var openBrace:Token;
	var members:Array<ClassMember>;
	var closeBrace:Token;
}

typedef InterfaceDecl = {
	var metadata:Array<Metadata>;
	var modifiers:Array<DeclModifier>;
	var keyword:Token;
	var name:Token;
	var extend:Null<{keyword:Token, paths:Separated<DotPath>}>;
	var openBrace:Token;
	var members:Array<InterfaceMember>;
	var closeBrace:Token;
}

enum ClassMember {
	MCondComp(v:CondCompVar, openBrace:Token, members:Array<ClassMember>, closeBrace:Token);
	MUseNamespace(n:UseNamespace, semicolon:Token);
	MField(f:ClassField);
	MStaticInit(block:BracedExprBlock);
}

typedef ClassField = {
	var metadata:Array<Metadata>;
	var namespace:Null<Token>;
	var modifiers:Array<ClassFieldModifier>;
	var kind:ClassFieldKind;
}

enum ClassFieldModifier {
	FMPublic(t:Token);
	FMPrivate(t:Token);
	FMProtected(t:Token);
	FMInternal(t:Token);
	FMOverride(t:Token);
	FMStatic(t:Token);
	FMFinal(t:Token);
}

enum ClassFieldKind {
	FVar(kind:VarDeclKind, vars:Separated<VarDecl>, semicolon:Token);
	FFun(keyword:Token, name:Token, fun:Function);
	FProp(keyword:Token, kind:PropKind, name:Token, fun:Function);
}

enum PropKind {
	PGet(keyword:Token);
	PSet(keyword:Token);
}

typedef BracedExprBlock = {
	var openBrace:Token;
	var exprs:Array<BlockElement>;
	var closeBrace:Token;
}

typedef FunctionSignature = {
	var openParen:Token;
	var args:Null<Separated<FunctionArg>>;
	var closeParen:Token;
	var ret:Null<TypeHint>;
}

typedef Function = {
	var signature:FunctionSignature;
	var block:BracedExprBlock;
}

enum FunctionArg {
	ArgNormal(a:VarDecl);
	ArgRest(dots:Token, name:Token);
}

enum InterfaceMember {
	MICondComp(v:CondCompVar, openBrace:Token, members:Array<InterfaceMember>, closeBrace:Token);
	MIField(f:InterfaceField);
}

typedef InterfaceField = {
	var metadata:Array<Metadata>;
	var kind:InterfaceFieldKind;
	var semicolon:Token;
}

enum InterfaceFieldKind {
	IFFun(keyword:Token, name:Token, fun:FunctionSignature);
	IFProp(keyword:Token, kind:PropKind, name:Token, fun:FunctionSignature);
}

typedef TypeHint = {
	var colon:Token;
	var type:SyntaxType;
}

typedef VarInit = {
	var equals:Token;
	var expr:Expr;
}

enum SyntaxType {
	TAny(star:Token);
	TPath(path:DotPath);
	TVector(v:VectorSyntax);
}

enum Expr {
	EIdent(i:Token);
	ELiteral(l:Literal);
	ECall(e:Expr, args:CallArgs);
	EParens(openParen:Token, e:Expr, closeParen:Token);
	EArrayAccess(e:Expr, openBracket:Token, eindex:Expr, closeBracket:Token);
	EArrayDecl(d:ArrayDecl);
	EReturn(keyword:Token, e:Null<Expr>);
	EThrow(keyword:Token, e:Expr);
	EDelete(keyword:Token, e:Expr);
	EBreak(keyword:Token);
	EContinue(keyword:Token);
	ENew(keyword:Token, e:Expr, args:Null<CallArgs>);
	EVectorDecl(newKeyword:Token, t:TypeParam, d:ArrayDecl);
	EField(e:Expr, dot:Token, fieldName:Token);
	EXmlAttr(e:Expr, dot:Token, at:Token, attrName:Token);
	EXmlAttrExpr(e:Expr, dot:Token, at:Token, openBrace:Token, eattr:Expr, closeBrace:Token);
	EXmlDescend(e:Expr, dotDot:Token, childName:Token);
	EBlock(b:BracedExprBlock);
	EObjectDecl(openBrace:Token, fields:Separated<ObjectField>, closeBrace:Token);
	EIf(keyword:Token, openParen:Token, econd:Expr, closeParen:Token, ethen:Expr, eelse:Null<{keyword:Token, expr:Expr}>);
	ETernary(econd:Expr, question:Token, ethen:Expr, colon:Token, eelse:Expr);
	EWhile(keyword:Token, openParen:Token, cond:Expr, closeParen:Token, body:Expr);
	EDoWhile(doKeyword:Token, body:Expr, whileKeyword:Token, openParen:Token, cond:Expr, closeParen:Token);
	EFor(f:For);
	EForIn(f:ForIn);
	EForEach(f:ForEach);
	EBinop(a:Expr, op:Binop, b:Expr);
	EPreUnop(op:PreUnop, e:Expr);
	EPostUnop(e:Expr, op:PostUnop);
	EVars(kind:VarDeclKind, vars:Separated<VarDecl>);
	EAs(e:Expr, keyword:Token, t:SyntaxType);
	EIs(e:Expr, keyword:Token, etype:Expr);
	EComma(a:Expr, comma:Token, b:Expr);
	EVector(v:VectorSyntax);
	ESwitch(keyword:Token, openParen:Token, subj:Expr, closeParen:Token, openBrace:Token, cases:Array<SwitchCase>, closeBrace:Token);
	ECondCompValue(v:CondCompVar);
	ECondCompBlock(v:CondCompVar, b:BracedExprBlock);
	ETry(keyword:Token, block:BracedExprBlock, catches:Array<Catch>, finally_:Null<Finally>);
	EFunction(keyword:Token, name:Null<Token>, fun:Function);
	EUseNamespace(n:UseNamespace);
}

typedef For = {keyword:Token, openParen:Token, einit:Null<Expr>, initSep:Token, econd:Null<Expr>, condSep:Token, eincr:Null<Expr>, closeParen:Token, body:Expr}
typedef ForIn = {forKeyword:Token, openParen:Token, iter:ForIter, closeParen:Token, body:Expr}
typedef ForEach = {forKeyword:Token, eachKeyword:Token, openParen:Token, iter:ForIter, closeParen:Token, body:Expr}

enum VarDeclKind {
	VVar(t:Token);
	VConst(t:Token);
}

typedef Catch = {
	var keyword:Token;
	var openParen:Token;
	var name:Token;
	var type:TypeHint;
	var closeParen:Token;
	var block:BracedExprBlock;
}

typedef Finally = {
	var keyword:Token;
	var block:BracedExprBlock;
}

typedef CondCompVar = {
	var ns:Token;
	var sep:Token;
	var name:Token;
}

typedef ForIter = {
	var eit:Expr;
	var inKeyword:Token;
	var eobj:Expr;
}

typedef ObjectField = {
	var name:Token;
	var colon:Token;
	var value:Expr;
}

enum SwitchCase {
	CCase(keyword:Token, v:Expr, colon:Token, body:Array<BlockElement>);
	CDefault(keyword:Token, colon:Token, body:Array<BlockElement>);
}

typedef VectorSyntax = {
	var name:Token;
	var dot:Token;
	var t:TypeParam;
}

typedef TypeParam = {
	var lt:Token;
	var type:SyntaxType;
	var gt:Token;
}

typedef ArrayDecl = {
	var openBracket:Token;
	var elems:Null<Separated<Expr>>;
	var closeBracket:Token;
}

enum PreUnop {
	PreNot(t:Token);
	PreNeg(t:Token);
	PreIncr(t:Token);
	PreDecr(t:Token);
	PreBitNeg(t:Token);
}

enum PostUnop {
	PostIncr(t:Token);
	PostDecr(t:Token);
}

typedef VarDecl = {
	var name:Token;
	var type:Null<TypeHint>;
	var init:Null<VarInit>;
}

enum Binop {
	OpAdd(t:Token);
	OpSub(t:Token);
	OpDiv(t:Token);
	OpMul(t:Token);
	OpMod(t:Token);
	OpAssign(t:Token);
	OpAssignAdd(t:Token);
	OpAssignSub(t:Token);
	OpAssignMul(t:Token);
	OpAssignDiv(t:Token);
	OpAssignMod(t:Token);
	OpAssignAnd(t:Token);
	OpAssignOr(t:Token);
	OpAssignBitAnd(t:Token);
	OpAssignBitOr(t:Token);
	OpAssignBitXor(t:Token);
	OpAssignShl(t:Token);
	OpAssignShr(t:Token);
	OpAssignUshr(t:Token);
	OpEquals(t:Token);
	OpNotEquals(t:Token);
	OpStrictEquals(t:Token);
	OpNotStrictEquals(t:Token);
	OpGt(t:Token);
	OpGte(t:Token);
	OpLt(t:Token);
	OpLte(t:Token);
	OpIn(t:Token);
	OpAnd(t:Token);
	OpOr(t:Token);
	OpShl(t:Token);
	OpShr(t:Token);
	OpUshr(t:Token);
	OpBitAnd(t:Token);
	OpBitOr(t:Token);
	OpBitXor(t:Token);
}

typedef BlockElement = {
	var expr:Expr;
	var semicolon:Null<Token>;
}

typedef CallArgs = {
	var openParen:Token;
	var args:Null<Separated<Expr>>;
	var closeParen:Token;
}

enum Literal {
	LString(t:Token);
	LDecInt(t:Token);
	LHexInt(t:Token);
	LFloat(t:Token);
	LRegExp(t:Token);
}

typedef Metadata = {
	var openBracket:Token;
	var name:Token;
	var args:Null<CallArgs>;
	var closeBracket:Token;
}